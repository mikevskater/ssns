---@class ClassifiedToken
---@field token Token The original token
---@field semantic_type string? Semantic type: "table", "view", "column", "schema", "database", "keyword", "procedure", "function", "alias", "cte", "temp_table", "unresolved"
---@field highlight_group string? Highlight group to use (e.g., "SsnsTable")

---@class Classifier
---Token classification logic for semantic highlighting
---Uses smart loading: only loads data for objects actually referenced in the buffer
local Classifier = {}

-- Import helper modules
local Loaders = require('nvim-ssns.highlighting.classifier_loaders')
local Resolvers = require('nvim-ssns.highlighting.classifier_resolvers')

-- Token types from tokenizer.lua
local TOKEN_TYPES = {
  KEYWORD = "keyword",
  IDENTIFIER = "identifier",
  BRACKET_ID = "bracket_id",
  STRING = "string",
  NUMBER = "number",
  OPERATOR = "operator",
  PAREN_OPEN = "paren_open",
  PAREN_CLOSE = "paren_close",
  COMMA = "comma",
  DOT = "dot",
  SEMICOLON = "semicolon",
  STAR = "star",
  GO = "go",
  AT = "at",
  VARIABLE = "variable",
  GLOBAL_VARIABLE = "global_variable",
  SYSTEM_PROCEDURE = "system_procedure",
  TEMP_TABLE = "temp_table",
  HASH = "hash",
  COMMENT = "comment",
  LINE_COMMENT = "line_comment",
}

-- Map semantic types to highlight groups
local HIGHLIGHT_MAP = {
  -- Legacy keyword (fallback for uncategorized)
  keyword = "SsnsKeyword",
  -- Keyword categories
  keyword_statement = "SsnsKeywordStatement",
  keyword_clause = "SsnsKeywordClause",
  keyword_function = "SsnsKeywordFunction",
  keyword_datatype = "SsnsKeywordDatatype",
  keyword_operator = "SsnsKeywordOperator",
  keyword_constraint = "SsnsKeywordConstraint",
  keyword_modifier = "SsnsKeywordModifier",
  keyword_misc = "SsnsKeywordMisc",
  keyword_global_variable = "SsnsKeywordGlobalVariable",
  keyword_system_procedure = "SsnsKeywordSystemProcedure",
  -- Database objects
  database = "SsnsDatabase",
  schema = "SsnsSchema",
  table = "SsnsTable",
  view = "SsnsView",
  procedure = "SsnsProcedure",
  ["function"] = "SsnsFunction",
  synonym = "SsnsSynonym",
  column = "SsnsColumn",
  alias = "SsnsAlias",
  cte = "SsnsTable",      -- CTEs use table color
  temp_table = "SsnsTempTable", -- Temp tables have distinct color
  operator = "SsnsOperator",
  string = "SsnsString",
  number = "SsnsNumber",
  parameter = "SsnsParameter", -- @parameters and @@system_variables
  unresolved = "SsnsUnresolved",
  comment = "SsnsComment",  -- Block and line comments
}

-- Keywords that indicate the next identifier is a database name
local DATABASE_CONTEXT_KEYWORDS = {
  USE = true,
}

-- Keywords that start a CREATE/ALTER context
local CREATE_ALTER_KEYWORDS = {
  CREATE = true,
  ALTER = true,
}

-- Keywords that indicate object type being created/altered
-- Maps keyword to semantic type for the object name
local CREATE_OBJECT_TYPE_KEYWORDS = {
  PROCEDURE = "procedure",
  PROC = "procedure",
  FUNCTION = "function",
  VIEW = "view",
  TRIGGER = "procedure",  -- Treat triggers like procedures
  TABLE = "table",        -- For CREATE TABLE column definition context
}

-- ============================================================================
-- Re-export loader functions for backwards compatibility
-- ============================================================================
Classifier._find_database = Loaders.find_database
Classifier._ensure_schemas_loaded = Loaders.ensure_schemas_loaded
Classifier._find_schema = Loaders.find_schema
Classifier._find_schema_in_connection = Loaders.find_schema_in_connection
Classifier._ensure_schema_objects_loaded = Loaders.ensure_schema_objects_loaded
Classifier._ensure_db_objects_loaded = Loaders.ensure_db_objects_loaded
Classifier._ensure_object_details_loaded = Loaders.ensure_object_details_loaded
Classifier._trigger_rehighlight = Loaders.trigger_rehighlight
Classifier._find_object_in_schema = Loaders.find_object_in_schema
Classifier._find_object_in_db = Loaders.find_object_in_db
Classifier._db_uses_schemas = Loaders.db_uses_schemas

-- Re-export resolver functions for backwards compatibility
Classifier._find_in_tree_cache = Resolvers.find_in_tree_cache
Classifier._find_schema_in_db = Resolvers.find_schema_in_db
Classifier._find_table_in_db = Resolvers.find_table_in_db
Classifier._find_routine_in_db = Resolvers.find_routine_in_db
Classifier._find_synonym_in_db = Resolvers.find_synonym_in_db
Classifier._find_column_in_object = Resolvers.find_column_in_object
Classifier._find_column_in_context_tables = Resolvers.find_column_in_context_tables
Classifier._resolve_table_ref_to_object = Resolvers.resolve_table_ref_to_object
Classifier._find_column_in_cache = Resolvers.find_column_in_cache
Classifier._find_column_in_loaded_objects = Resolvers.find_column_in_loaded_objects
Classifier._resolve_multipart_from_cache = Resolvers.resolve_multipart_from_cache
Classifier._resolve_as_database_qualified = Resolvers.resolve_as_database_qualified

---Classify all tokens in the buffer
---@param tokens Token[] Array of tokens from tokenizer
---@param chunks StatementChunk[] Parsed statement chunks
---@param connection table? Connection context for database lookups
---@param config SemanticHighlightingConfig Highlighting configuration
---@return ClassifiedToken[] classified Array of classified tokens
function Classifier.classify(tokens, chunks, connection, config)
  local classified = {}

  -- Build index for quick chunk lookup by position
  local chunk_index = Classifier._build_chunk_index(chunks)

  -- Track the last keyword for context (only for USE database detection)
  local last_keyword = nil

  -- Track CREATE/ALTER context: when we see CREATE/ALTER followed by PROCEDURE/FUNCTION,
  -- the next identifier should be highlighted as that object type even if not in cache
  local in_create_alter = false  -- True after seeing CREATE or ALTER
  local create_object_type = nil  -- "procedure", "function", etc. after seeing the object type keyword

  -- Track CREATE TABLE column definition context
  local in_create_table_def = false  -- True when inside CREATE TABLE (...) column definitions
  local create_table_paren_depth = 0  -- Paren depth within CREATE TABLE definition
  local expect_column_name = false   -- True when next identifier should be a column name

  -- Track constraint column list context (PRIMARY KEY, FOREIGN KEY, UNIQUE, REFERENCES)
  local expect_constraint_columns = false  -- True after seeing PRIMARY KEY, FOREIGN KEY, UNIQUE, REFERENCES
  local in_constraint_column_list = false  -- True when inside (...) after constraint keywords
  local constraint_paren_depth = 0         -- Paren depth within constraint column list

  -- Track previous token for parameter detection (identifier following @)
  local prev_token = nil

  -- Gather multi-part identifiers (sequences of IDENTIFIER/BRACKET_ID separated by DOT)
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local result = nil

    if token.type == TOKEN_TYPES.KEYWORD or token.type == TOKEN_TYPES.GO then
      -- SQL keyword
      local keyword_upper = token.text:upper()
      last_keyword = keyword_upper

      -- Track CREATE/ALTER context
      if CREATE_ALTER_KEYWORDS[keyword_upper] then
        in_create_alter = true
        create_object_type = nil  -- Reset until we see PROCEDURE/FUNCTION
      elseif in_create_alter and CREATE_OBJECT_TYPE_KEYWORDS[keyword_upper] then
        -- We're in CREATE/ALTER and just saw PROCEDURE, FUNCTION, etc.
        create_object_type = CREATE_OBJECT_TYPE_KEYWORDS[keyword_upper]
      elseif keyword_upper == "OR" then
        -- Keep in_create_alter for "CREATE OR ALTER"
      else
        -- Any other keyword resets the CREATE context (unless it's OR)
        if not (keyword_upper == "OR") then
          in_create_alter = false
          create_object_type = nil
        end
      end

      -- Track constraint column list context (for PRIMARY KEY, FOREIGN KEY, UNIQUE, REFERENCES)
      if keyword_upper == "CONSTRAINT" then
        -- After CONSTRAINT, next identifier is constraint name, not column
        expect_column_name = false
        expect_constraint_columns = false
      elseif keyword_upper == "KEY" then
        -- PRIMARY KEY or FOREIGN KEY - expect column list in next parens
        local prev_upper = prev_token and prev_token.text and prev_token.text:upper()
        if prev_upper == "PRIMARY" or prev_upper == "FOREIGN" then
          expect_constraint_columns = true
        end
      elseif keyword_upper == "UNIQUE" or keyword_upper == "REFERENCES" then
        -- UNIQUE constraint or REFERENCES - expect column list in next parens
        expect_constraint_columns = true
      elseif keyword_upper == "INDEX" then
        -- INDEX - expect column list in next parens (for CREATE INDEX or inline)
        expect_constraint_columns = true
      end

      if config.highlight_keywords then
        -- Determine specific semantic type based on keyword category
        local category = token.keyword_category or "misc"
        local semantic_type = "keyword_" .. category
        local highlight_group = HIGHLIGHT_MAP[semantic_type] or HIGHLIGHT_MAP.keyword

        result = {
          token = token,
          semantic_type = semantic_type,
          highlight_group = highlight_group,
        }
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.STRING then
      -- String literal
      result = {
        token = token,
        semantic_type = "string",
        highlight_group = HIGHLIGHT_MAP.string,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.NUMBER then
      -- Number literal
      result = {
        token = token,
        semantic_type = "number",
        highlight_group = HIGHLIGHT_MAP.number,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.OPERATOR then
      -- Operator
      result = {
        token = token,
        semantic_type = "operator",
        highlight_group = HIGHLIGHT_MAP.operator,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.IDENTIFIER or token.type == TOKEN_TYPES.BRACKET_ID then
      -- Check if this identifier follows @ (parameter name)
      if prev_token and prev_token.type == TOKEN_TYPES.AT then
        -- This is a parameter/variable name
        if config.highlight_parameters then
          result = {
            token = token,
            semantic_type = "parameter",
            highlight_group = HIGHLIGHT_MAP.parameter,
          }
        end
        prev_token = token
        i = i + 1
      elseif in_constraint_column_list and constraint_paren_depth == 1 then
        -- This is a column reference in constraint column list (PRIMARY KEY, FOREIGN KEY, etc.)
        result = {
          token = token,
          semantic_type = "column",
          highlight_group = HIGHLIGHT_MAP.column,
        }
        prev_token = token
        i = i + 1
      elseif expect_column_name and in_create_table_def then
        -- This is a column name in CREATE TABLE definition
        result = {
          token = token,
          semantic_type = "column",
          highlight_group = HIGHLIGHT_MAP.column,
        }
        expect_column_name = false  -- Next identifier is datatype, not column
        prev_token = token
        i = i + 1
      else
        -- Identifier - check if part of multi-part identifier
        local parts, consumed = Classifier._gather_multipart(tokens, i)
        local chunk = Classifier._find_chunk_at_position(chunk_index, token.line, token.col)

        -- Build keyword context for special handling
        local keyword_context = {
          is_database_context = last_keyword and DATABASE_CONTEXT_KEYWORDS[last_keyword],
          create_object_type = create_object_type,  -- "procedure", "function", etc. when in CREATE context
        }

        -- Classify each part by resolving against cache
        local part_results = Classifier._classify_multipart(parts, chunk, connection, config, keyword_context)
        for _, part_result in ipairs(part_results) do
          table.insert(classified, part_result)
        end

        -- Reset context after consuming identifier
        last_keyword = nil
        -- Reset CREATE context after consuming the object name
        -- But keep TABLE context for column definition detection
        if create_object_type and create_object_type ~= "table" then
          in_create_alter = false
          create_object_type = nil
        end

        prev_token = token
        i = i + consumed
        -- Skip adding result since we added directly
        result = nil
      end

    elseif token.type == TOKEN_TYPES.TEMP_TABLE then
      -- Temp table token (#temp or ##global_temp)
      -- The entire name including # is now in a single token
      result = {
        token = token,
        semantic_type = "temp_table",
        highlight_group = HIGHLIGHT_MAP.temp_table,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.HASH then
      -- Lone hash token (rare case, just skip)
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.AT then
      -- @ symbol starts a parameter/variable (@UserId)
      -- Look ahead for identifier to highlight the @ as parameter
      if i + 1 <= #tokens then
        local next_token = tokens[i + 1]
        if next_token.type == TOKEN_TYPES.IDENTIFIER then
          -- Valid parameter/variable start
          if config.highlight_parameters then
            result = {
              token = token,
              semantic_type = "parameter",
              highlight_group = HIGHLIGHT_MAP.parameter,
            }
          end
        end
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.GLOBAL_VARIABLE then
      -- @@ system global variable (@@ROWCOUNT, @@VERSION, etc.)
      -- These are now tokenized as a single GLOBAL_VARIABLE token
      if config.highlight_parameters then
        result = {
          token = token,
          semantic_type = "keyword_global_variable",
          highlight_group = HIGHLIGHT_MAP.keyword_global_variable,
        }
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.VARIABLE then
      -- @variable user variable/parameter (@UserId, @startCount, etc.)
      -- These are now tokenized as a single VARIABLE token
      if config.highlight_parameters then
        result = {
          token = token,
          semantic_type = "parameter",
          highlight_group = HIGHLIGHT_MAP.parameter,
        }
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.SYSTEM_PROCEDURE then
      -- System stored procedures (sp_*, xp_*, DBCC)
      -- These are tokenized as SYSTEM_PROCEDURE tokens
      result = {
        token = token,
        semantic_type = "keyword_system_procedure",
        highlight_group = HIGHLIGHT_MAP.keyword_system_procedure,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.SEMICOLON then
      -- Semicolon resets keyword context (new statement)
      last_keyword = nil
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.COMMENT or token.type == TOKEN_TYPES.LINE_COMMENT then
      -- Comment token (block or line comment)
      result = {
        token = token,
        semantic_type = "comment",
        highlight_group = HIGHLIGHT_MAP.comment,
      }
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.PAREN_OPEN then
      -- Track constraint column list context (PRIMARY KEY, FOREIGN KEY, UNIQUE, REFERENCES)
      if expect_constraint_columns then
        -- Entering constraint column list (e.g., PRIMARY KEY ([col1], [col2]))
        in_constraint_column_list = true
        constraint_paren_depth = 1
        expect_constraint_columns = false
      elseif in_constraint_column_list then
        -- Nested paren within constraint (rare but possible)
        constraint_paren_depth = constraint_paren_depth + 1
      end

      -- Track CREATE TABLE column definition context
      if create_object_type == "table" and not in_create_table_def then
        -- Entering CREATE TABLE (...) definition for the first time
        in_create_table_def = true
        create_table_paren_depth = 1
        expect_column_name = true
      elseif in_create_table_def then
        -- Already inside CREATE TABLE - track nested parens (e.g., IDENTITY(1,1), CHECK(...))
        create_table_paren_depth = create_table_paren_depth + 1
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.PAREN_CLOSE then
      -- Track constraint column list context
      if in_constraint_column_list then
        constraint_paren_depth = constraint_paren_depth - 1
        if constraint_paren_depth <= 0 then
          -- Exiting constraint column list
          in_constraint_column_list = false
          constraint_paren_depth = 0
        end
      end

      -- Track CREATE TABLE column definition context
      if in_create_table_def then
        create_table_paren_depth = create_table_paren_depth - 1
        if create_table_paren_depth <= 0 then
          -- Exiting CREATE TABLE definition (closing the main paren)
          in_create_table_def = false
          create_table_paren_depth = 0
          expect_column_name = false
          create_object_type = nil
          in_create_alter = false
        end
      end
      prev_token = token
      i = i + 1

    elseif token.type == TOKEN_TYPES.COMMA then
      -- In CREATE TABLE context, comma separates column definitions
      if in_create_table_def and create_table_paren_depth == 1 then
        expect_column_name = true
      end
      prev_token = token
      i = i + 1

    else
      -- Other tokens (DOT, STAR) - skip
      prev_token = token
      i = i + 1
    end

    if result then
      table.insert(classified, result)
    end
  end

  return classified
end

---Gather a multi-part identifier (e.g., database.schema.table.column)
---@param tokens Token[] All tokens
---@param start_idx number Starting index
---@return Token[] parts Array of identifier tokens
---@return number consumed Number of tokens consumed
function Classifier._gather_multipart(tokens, start_idx)
  local parts = {}
  local i = start_idx

  while i <= #tokens do
    local token = tokens[i]

    if token.type == TOKEN_TYPES.IDENTIFIER or token.type == TOKEN_TYPES.BRACKET_ID then
      table.insert(parts, token)
      i = i + 1

      -- Check for DOT
      if i <= #tokens and tokens[i].type == TOKEN_TYPES.DOT then
        i = i + 1 -- consume dot
        -- Continue to next identifier
      else
        break -- No more parts
      end
    elseif token.type == TOKEN_TYPES.HASH then
      -- Hash prefix for temp tables
      i = i + 1
      -- Continue to get the identifier
    else
      break
    end
  end

  return parts, i - start_idx
end

---Classify a multi-part identifier by resolving each part against the cache
---@param parts Token[] Array of identifier tokens
---@param chunk StatementChunk? The statement chunk containing this identifier
---@param connection table? Connection context
---@param config SemanticHighlightingConfig Configuration
---@param keyword_context table? Context from previous keywords {last_keyword, in_table_context, is_database_context}
---@return ClassifiedToken[] results Classified tokens for each part
function Classifier._classify_multipart(parts, chunk, connection, config, keyword_context)
  local results = {}
  keyword_context = keyword_context or {}

  if #parts == 0 then
    return results
  end

  -- Extract names from tokens (strip brackets if present)
  local names = {}
  for _, part in ipairs(parts) do
    local name = Classifier._strip_brackets(part.text)
    table.insert(names, name)
  end

  -- Build context for resolution (aliases, CTEs, temp tables from chunk)
  -- Pass token position for CTE body detection
  local first_part = parts[1]
  local sql_context = Classifier._build_context(chunk, first_part.line, first_part.col)

  -- Get clause position for context-aware disambiguation
  -- This helps when objects aren't loaded yet (FROM -> schema.table, SELECT -> alias.column)
  local clause = nil
  if chunk and parts[1] then
    local StatementParser = require('nvim-ssns.completion.statement_parser')
    clause = StatementParser.get_clause_at_position(chunk, parts[1].line, parts[1].col)
  end

  -- Build resolution context with clause info and CREATE context
  local resolution_context = {
    is_database_context = keyword_context.is_database_context,
    clause = clause,  -- "from", "select", "where", "join", "on", "group_by", "having", "order_by", etc.
    create_object_type = keyword_context.create_object_type,  -- "procedure", "function", etc. in CREATE statements
  }

  -- Resolve each part against the cache, building context as we go
  local resolved_types = Resolvers.resolve_multipart_from_cache(names, sql_context, connection, resolution_context)

  -- Build results from resolved types
  for i, part in ipairs(parts) do
    local semantic_type = resolved_types[i] or "unresolved"
    local highlight_group = nil

    -- Map semantic type to highlight group based on config
    if semantic_type == "database" and config.highlight_databases then
      highlight_group = HIGHLIGHT_MAP.database
    elseif semantic_type == "schema" and config.highlight_schemas then
      highlight_group = HIGHLIGHT_MAP.schema
    elseif semantic_type == "table" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.table
    elseif semantic_type == "view" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.view
    elseif semantic_type == "column" and config.highlight_columns then
      highlight_group = HIGHLIGHT_MAP.column
    elseif semantic_type == "alias" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.alias
    elseif semantic_type == "cte" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.cte
    elseif semantic_type == "temp_table" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.temp_table
    elseif semantic_type == "procedure" then
      highlight_group = HIGHLIGHT_MAP.procedure
    elseif semantic_type == "function" then
      highlight_group = HIGHLIGHT_MAP["function"]
    elseif semantic_type == "synonym" then
      highlight_group = HIGHLIGHT_MAP.synonym
    elseif semantic_type == "unresolved" and config.highlight_unresolved then
      highlight_group = HIGHLIGHT_MAP.unresolved
    end

    table.insert(results, {
      token = part,
      semantic_type = semantic_type,
      highlight_group = highlight_group,
    })
  end

  return results
end

---Check if a position is inside a CTE body
---@param cte CTEInfo CTE to check
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean inside True if position is inside CTE body
local function is_inside_cte(cte, line, col)
  if not cte.start_pos or not cte.end_pos then
    return false
  end

  local start_line, start_col = cte.start_pos.line, cte.start_pos.col
  local end_line, end_col = cte.end_pos.line, cte.end_pos.col

  -- Before start
  if line < start_line or (line == start_line and col < start_col) then
    return false
  end

  -- After end
  if line > end_line or (line == end_line and col > end_col) then
    return false
  end

  return true
end

---Build context from statement chunk
---@param chunk StatementChunk? Statement chunk
---@param line number? Token line for CTE context detection
---@param col number? Token column for CTE context detection
---@return table context Context with aliases, ctes, temp_tables, tables
function Classifier._build_context(chunk, line, col)
  local context = {
    aliases = {},
    ctes = {},
    temp_tables = {},
    tables = {},
  }

  if not chunk then
    return context
  end

  -- Check if position is inside a CTE body - if so, use CTE's context
  local inside_cte = nil
  if line and col and chunk.ctes then
    for _, cte in ipairs(chunk.ctes) do
      if is_inside_cte(cte, line, col) then
        inside_cte = cte
        break
      end
    end
  end

  -- If inside a CTE, use that CTE's tables and aliases as primary context
  if inside_cte then
    -- Add CTE's internal aliases
    if inside_cte.aliases then
      for alias_name, table_ref in pairs(inside_cte.aliases) do
        context.aliases[alias_name:lower()] = table_ref
      end
    end

    -- Add CTE's internal tables
    if inside_cte.tables then
      for _, tbl in ipairs(inside_cte.tables) do
        table.insert(context.tables, tbl)
        -- Also add alias if present (redundant with above but ensures consistency)
        if tbl.alias then
          context.aliases[tbl.alias:lower()] = tbl.name or tbl.table
        end
      end
    end

    -- Add nested subquery aliases from CTE
    if inside_cte.subqueries then
      for _, subquery in ipairs(inside_cte.subqueries) do
        if subquery.alias then
          context.aliases[subquery.alias:lower()] = "(subquery)"
        end
      end
    end
  end

  -- Extract chunk-level aliases (from main statement)
  if chunk.aliases then
    for alias_name, table_ref in pairs(chunk.aliases) do
      -- Don't override CTE-internal aliases
      if not context.aliases[alias_name:lower()] then
        context.aliases[alias_name:lower()] = table_ref
      end
    end
  end

  -- Extract CTEs (always available for CTE name recognition)
  if chunk.ctes then
    for _, cte in ipairs(chunk.ctes) do
      if cte.name then
        context.ctes[cte.name:lower()] = cte
      end
    end
  end

  -- Extract tables from main statement (only if not inside a CTE)
  if not inside_cte and chunk.tables then
    for _, tbl in ipairs(chunk.tables) do
      table.insert(context.tables, tbl)
      -- Also add alias if present
      if tbl.alias then
        context.aliases[tbl.alias:lower()] = tbl.name or tbl.table
      end
    end
  end

  -- Extract subquery aliases from main statement (only if not inside a CTE)
  if not inside_cte and chunk.subqueries then
    for _, subquery in ipairs(chunk.subqueries) do
      if subquery.alias then
        -- Subquery aliases map to a placeholder indicating it's a derived table
        context.aliases[subquery.alias:lower()] = "(subquery)"
      end
    end
  end

  return context
end

---Build index for quick chunk lookup by line
---Provides O(1) lookup by line number instead of linear scan
---@param chunks StatementChunk[] Statement chunks
---@return table index Lookup table mapping line -> chunk
function Classifier._build_chunk_index(chunks)
  local index = {}
  for _, chunk in ipairs(chunks or {}) do
    -- Index chunks by their line range
    if chunk.start_line and chunk.end_line then
      for line = chunk.start_line, chunk.end_line do
        index[line] = index[line] or chunk
      end
    end
  end
  return index
end

---Find chunk at position with boundary line column validation
---Column checks only matter on boundary lines (first/last line of chunk)
---Middle lines are always valid since the statement spans the entire line
---@param index table Chunk index
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk
function Classifier._find_chunk_at_position(index, line, col)
  local chunk = index[line]
  if not chunk then
    return nil
  end

  -- Column validation only on boundary lines:
  -- - First line: cursor must be at or after start_col
  -- - Last line: allow tolerance for typing continuation
  -- - Middle lines: any column is valid

  if line == chunk.start_line and col < chunk.start_col then
    return nil
  end

  if line == chunk.end_line and col > chunk.end_col + 50 then
    return nil
  end

  return chunk
end

---Strip brackets from identifier
---@param text string Token text
---@return string name Identifier without brackets
function Classifier._strip_brackets(text)
  -- Remove [brackets] or "quotes" or `backticks`
  local name = text
  name = name:gsub("^%[(.-)%]$", "%1")
  name = name:gsub('^"(.-)"$', "%1")
  name = name:gsub("^`(.-)`$", "%1")
  return name
end

return Classifier
