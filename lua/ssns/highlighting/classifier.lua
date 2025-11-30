---@class ClassifiedToken
---@field token Token The original token
---@field semantic_type string? Semantic type: "table", "view", "column", "schema", "database", "keyword", "procedure", "function", "alias", "cte", "temp_table", "unresolved"
---@field highlight_group string? Highlight group to use (e.g., "SsnsTable")

---@class Classifier
---Token classification logic for semantic highlighting
local Classifier = {}

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
  HASH = "hash",
}

-- Map semantic types to highlight groups
local HIGHLIGHT_MAP = {
  keyword = "SsnsKeyword",
  database = "SsnsDatabase",
  schema = "SsnsSchema",
  table = "SsnsTable",
  view = "SsnsView",
  procedure = "SsnsProcedure",
  ["function"] = "SsnsFunction",
  column = "SsnsColumn",
  alias = "SsnsAlias",
  cte = "SsnsTable",      -- CTEs use table color
  temp_table = "SsnsTable", -- Temp tables use table color
  operator = "SsnsOperator",
  string = "SsnsString",
  number = "SsnsNumber",
  unresolved = "SsnsUnresolved",
}

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

  -- Gather multi-part identifiers (sequences of IDENTIFIER/BRACKET_ID separated by DOT)
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local result = nil

    if token.type == TOKEN_TYPES.KEYWORD or token.type == TOKEN_TYPES.GO then
      -- SQL keyword
      if config.highlight_keywords then
        result = {
          token = token,
          semantic_type = "keyword",
          highlight_group = HIGHLIGHT_MAP.keyword,
        }
      end
      i = i + 1

    elseif token.type == TOKEN_TYPES.STRING then
      -- String literal
      result = {
        token = token,
        semantic_type = "string",
        highlight_group = HIGHLIGHT_MAP.string,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.NUMBER then
      -- Number literal
      result = {
        token = token,
        semantic_type = "number",
        highlight_group = HIGHLIGHT_MAP.number,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.OPERATOR then
      -- Operator
      result = {
        token = token,
        semantic_type = "operator",
        highlight_group = HIGHLIGHT_MAP.operator,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.IDENTIFIER or token.type == TOKEN_TYPES.BRACKET_ID then
      -- Identifier - check if part of multi-part identifier
      local parts, consumed = Classifier._gather_multipart(tokens, i)
      local chunk = Classifier._find_chunk_at_position(chunk_index, token.line, token.col)

      -- Classify each part
      local part_results = Classifier._classify_multipart(parts, chunk, connection, config)
      for _, part_result in ipairs(part_results) do
        table.insert(classified, part_result)
      end

      i = i + consumed
      -- Skip adding result since we added directly
      result = nil

    elseif token.type == TOKEN_TYPES.HASH then
      -- Hash token (start of temp table name)
      -- Look ahead for identifier
      if i + 1 <= #tokens then
        local next_token = tokens[i + 1]
        if next_token.type == TOKEN_TYPES.IDENTIFIER or next_token.type == TOKEN_TYPES.BRACKET_ID then
          -- Highlight the hash as temp table
          result = {
            token = token,
            semantic_type = "temp_table",
            highlight_group = HIGHLIGHT_MAP.temp_table,
          }
        end
      end
      i = i + 1

    elseif token.type == TOKEN_TYPES.AT then
      -- Variable/parameter - skip for now (could add SsnsVariable highlight)
      i = i + 1

    else
      -- Other tokens (DOT, COMMA, PAREN, SEMICOLON, STAR) - skip
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

---Classify a multi-part identifier
---@param parts Token[] Array of identifier tokens
---@param chunk StatementChunk? The statement chunk containing this identifier
---@param connection table? Connection context
---@param config SemanticHighlightingConfig Configuration
---@return ClassifiedToken[] results Classified tokens for each part
function Classifier._classify_multipart(parts, chunk, connection, config)
  local results = {}

  if #parts == 0 then
    return results
  end

  -- Extract names from tokens (strip brackets if present)
  local names = {}
  for _, part in ipairs(parts) do
    local name = Classifier._strip_brackets(part.text)
    table.insert(names, name)
  end

  -- Build context for resolution
  local context = Classifier._build_context(chunk)

  -- Classify based on number of parts
  if #parts == 1 then
    -- Single identifier: could be table, column, alias, CTE, or temp table
    local result = Classifier._classify_single(parts[1], names[1], chunk, context, connection, config)
    table.insert(results, result)

  elseif #parts == 2 then
    -- Two parts: table.column OR schema.table
    local part1_result, part2_result = Classifier._classify_two_parts(parts, names, chunk, context, connection, config)
    table.insert(results, part1_result)
    table.insert(results, part2_result)

  elseif #parts == 3 then
    -- Three parts: schema.table.column OR database.schema.table
    local results_array = Classifier._classify_three_parts(parts, names, chunk, context, connection, config)
    for _, r in ipairs(results_array) do
      table.insert(results, r)
    end

  elseif #parts == 4 then
    -- Four parts: database.schema.table.column
    local results_array = Classifier._classify_four_parts(parts, names, chunk, context, connection, config)
    for _, r in ipairs(results_array) do
      table.insert(results, r)
    end

  else
    -- More than 4 parts: mark as unresolved
    for _, part in ipairs(parts) do
      table.insert(results, {
        token = part,
        semantic_type = "unresolved",
        highlight_group = config.highlight_unresolved and HIGHLIGHT_MAP.unresolved or nil,
      })
    end
  end

  return results
end

---Classify a single identifier
---@param token Token The token
---@param name string The identifier name (without brackets)
---@param chunk StatementChunk? Statement chunk
---@param context table Context with aliases, CTEs, temp tables
---@param connection table? Connection context
---@param config SemanticHighlightingConfig Configuration
---@return ClassifiedToken result
function Classifier._classify_single(token, name, chunk, context, connection, config)
  local name_lower = name:lower()

  -- Check if it's an alias
  if context.aliases[name_lower] then
    return {
      token = token,
      semantic_type = "alias",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.alias or nil,
    }
  end

  -- Check if it's a CTE name
  if context.ctes[name_lower] then
    return {
      token = token,
      semantic_type = "cte",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.cte or nil,
    }
  end

  -- Check if it's a temp table
  if name:match("^#") or context.temp_tables[name_lower] then
    return {
      token = token,
      semantic_type = "temp_table",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.temp_table or nil,
    }
  end

  -- Check if it's a known table name in the chunk
  for _, tbl in ipairs(context.tables) do
    local tbl_name = tbl.name or tbl.table
    if tbl_name and tbl_name:lower() == name_lower then
      return {
        token = token,
        semantic_type = "table",
        highlight_group = config.highlight_tables and HIGHLIGHT_MAP.table or nil,
      }
    end
  end

  -- Check if it's a column from any table in scope
  if config.highlight_columns and Classifier._is_column_in_scope(name, context, connection) then
    return {
      token = token,
      semantic_type = "column",
      highlight_group = HIGHLIGHT_MAP.column,
    }
  end

  -- Try to resolve against database
  if connection and connection.database then
    local resolved = Classifier._resolve_identifier(name, connection)
    if resolved then
      return {
        token = token,
        semantic_type = resolved.type,
        highlight_group = HIGHLIGHT_MAP[resolved.type],
      }
    end
  end

  -- Unresolved
  return {
    token = token,
    semantic_type = "unresolved",
    highlight_group = config.highlight_unresolved and HIGHLIGHT_MAP.unresolved or nil,
  }
end

---Classify two-part identifier (table.column or schema.table)
---@return ClassifiedToken part1, ClassifiedToken part2
function Classifier._classify_two_parts(parts, names, chunk, context, connection, config)
  local name1 = names[1]
  local name2 = names[2]
  local name1_lower = name1:lower()
  local name2_lower = name2:lower()

  -- Check if first part is an alias -> alias.column
  if context.aliases[name1_lower] then
    return {
      token = parts[1],
      semantic_type = "alias",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.alias or nil,
    }, {
      token = parts[2],
      semantic_type = "column",
      highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
    }
  end

  -- Check if first part is a CTE -> cte.column
  if context.ctes[name1_lower] then
    return {
      token = parts[1],
      semantic_type = "cte",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.cte or nil,
    }, {
      token = parts[2],
      semantic_type = "column",
      highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
    }
  end

  -- Check if first part is a table in scope -> table.column
  for _, tbl in ipairs(context.tables) do
    local tbl_name = tbl.name or tbl.table
    if tbl_name and tbl_name:lower() == name1_lower then
      return {
        token = parts[1],
        semantic_type = "table",
        highlight_group = config.highlight_tables and HIGHLIGHT_MAP.table or nil,
      }, {
        token = parts[2],
        semantic_type = "column",
        highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
      }
    end
  end

  -- Assume schema.table pattern
  return {
    token = parts[1],
    semantic_type = "schema",
    highlight_group = config.highlight_schemas and HIGHLIGHT_MAP.schema or nil,
  }, {
    token = parts[2],
    semantic_type = "table",
    highlight_group = config.highlight_tables and HIGHLIGHT_MAP.table or nil,
  }
end

---Classify three-part identifier
---@return ClassifiedToken[] results
function Classifier._classify_three_parts(parts, names, chunk, context, connection, config)
  local name1 = names[1]
  local name2 = names[2]
  local name1_lower = name1:lower()
  local name2_lower = name2:lower()

  -- Check if first part is an alias/table -> alias.*.column (error, but handle)
  -- More likely: schema.table.column
  if context.aliases[name1_lower] or context.ctes[name1_lower] then
    -- alias.something.column - first is alias, second is unknown, third is column
    return {
      {
        token = parts[1],
        semantic_type = "alias",
        highlight_group = config.highlight_tables and HIGHLIGHT_MAP.alias or nil,
      },
      {
        token = parts[2],
        semantic_type = "unresolved",
        highlight_group = config.highlight_unresolved and HIGHLIGHT_MAP.unresolved or nil,
      },
      {
        token = parts[3],
        semantic_type = "column",
        highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
      },
    }
  end

  -- Default: schema.table.column
  return {
    {
      token = parts[1],
      semantic_type = "schema",
      highlight_group = config.highlight_schemas and HIGHLIGHT_MAP.schema or nil,
    },
    {
      token = parts[2],
      semantic_type = "table",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.table or nil,
    },
    {
      token = parts[3],
      semantic_type = "column",
      highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
    },
  }
end

---Classify four-part identifier (database.schema.table.column)
---@return ClassifiedToken[] results
function Classifier._classify_four_parts(parts, names, chunk, context, connection, config)
  return {
    {
      token = parts[1],
      semantic_type = "database",
      highlight_group = config.highlight_databases and HIGHLIGHT_MAP.database or nil,
    },
    {
      token = parts[2],
      semantic_type = "schema",
      highlight_group = config.highlight_schemas and HIGHLIGHT_MAP.schema or nil,
    },
    {
      token = parts[3],
      semantic_type = "table",
      highlight_group = config.highlight_tables and HIGHLIGHT_MAP.table or nil,
    },
    {
      token = parts[4],
      semantic_type = "column",
      highlight_group = config.highlight_columns and HIGHLIGHT_MAP.column or nil,
    },
  }
end

---Build context from statement chunk
---@param chunk StatementChunk? Statement chunk
---@return table context Context with aliases, ctes, temp_tables, tables
function Classifier._build_context(chunk)
  local context = {
    aliases = {},
    ctes = {},
    temp_tables = {},
    tables = {},
  }

  if not chunk then
    return context
  end

  -- Extract aliases
  if chunk.aliases then
    for alias_name, table_ref in pairs(chunk.aliases) do
      context.aliases[alias_name:lower()] = table_ref
    end
  end

  -- Extract CTEs
  if chunk.ctes then
    for _, cte in ipairs(chunk.ctes) do
      if cte.name then
        context.ctes[cte.name:lower()] = cte
      end
    end
  end

  -- Extract tables
  if chunk.tables then
    for _, tbl in ipairs(chunk.tables) do
      table.insert(context.tables, tbl)
      -- Also add alias if present
      if tbl.alias then
        context.aliases[tbl.alias:lower()] = tbl.name or tbl.table
      end
    end
  end

  return context
end

---Build index for quick chunk lookup by line
---@param chunks StatementChunk[] Statement chunks
---@return table index Lookup table
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

---Find chunk at position
---@param index table Chunk index
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk
function Classifier._find_chunk_at_position(index, line, col)
  return index[line]
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

---Check if a name is a column in any table in scope
---@param name string Column name
---@param context table Context with tables
---@param connection table? Connection context
---@return boolean
function Classifier._is_column_in_scope(name, context, connection)
  if not connection or not connection.database then
    return false
  end

  -- Check columns from tables in scope
  for _, tbl in ipairs(context.tables) do
    -- If table has inline columns (CTEs, subqueries, temp tables)
    if tbl.columns then
      for _, col in ipairs(tbl.columns) do
        local col_name = type(col) == "table" and col.name or col
        if col_name and col_name:lower() == name:lower() then
          return true
        end
      end
    end
  end

  return false
end

---Resolve identifier against database
---@param name string Identifier name
---@param connection table Connection context
---@return table? resolved { type = "table"|"view"|"schema"|"database"|"procedure"|"function" }
function Classifier._resolve_identifier(name, connection)
  if not connection or not connection.database then
    return nil
  end

  local Cache = require('ssns.cache')

  -- Try to find as table
  local table_obj = Cache.find_table(name)
  if table_obj then
    return { type = "table" }
  end

  -- Try to find as view
  local view_obj = Cache.find_view and Cache.find_view(name)
  if view_obj then
    return { type = "view" }
  end

  -- Try to find as schema
  local schema_obj = Cache.find_schema and Cache.find_schema(name)
  if schema_obj then
    return { type = "schema" }
  end

  -- Try to find as database
  local database_obj = Cache.find_database and Cache.find_database(name)
  if database_obj then
    return { type = "database" }
  end

  return nil
end

return Classifier
