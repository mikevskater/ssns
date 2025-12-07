---@class ClassifiedToken
---@field token Token The original token
---@field semantic_type string? Semantic type: "table", "view", "column", "schema", "database", "keyword", "procedure", "function", "alias", "cte", "temp_table", "unresolved"
---@field highlight_group string? Highlight group to use (e.g., "SsnsTable")

---@class Classifier
---Token classification logic for semantic highlighting
---Uses smart loading: only loads data for objects actually referenced in the buffer
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
  GLOBAL_VARIABLE = "global_variable",
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
  temp_table = "SsnsTable", -- Temp tables use table color
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
}

-- ============================================================================
-- Smart Loading Helpers
-- These functions ensure data is loaded on-demand as the classifier encounters
-- references in the SQL buffer. This provides semantic highlighting without
-- loading all databases upfront.
-- ============================================================================

---Find a database by name across all servers
---@param name string Database name (case-insensitive)
---@return DbClass? database The database if found
---@return ServerClass? server The server containing the database
function Classifier._find_database(name)
  local Cache = require('ssns.cache')
  local name_lower = name:lower()
  
  for _, server in ipairs(Cache.servers or {}) do
    for _, db in ipairs(server:get_databases()) do
      local db_name = db.db_name or db.name
      if db_name and db_name:lower() == name_lower then
        return db, server
      end
    end
  end
  return nil, nil
end

---Ensure a database's schemas are loaded (for schema-based servers)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param db DbClass The database to ensure schemas for
---@return boolean is_loaded True if schemas are already loaded and available now
function Classifier._ensure_schemas_loaded(db)
  if not db then return false end
  
  -- Already have schemas - data is available
  if db.schemas then
    return true
  end
  
  -- Not loaded - schedule load for next tick (non-blocking)
  if not db._schemas_loading_scheduled then
    db._schemas_loading_scheduled = true
    vim.schedule(function()
      -- Use the database's internal method if available
      if db._ensure_schemas_loaded then
        db:_ensure_schemas_loaded()
      else
        db:get_schemas()
      end
      db._schemas_loading_scheduled = false
      -- Re-trigger semantic highlighting after load completes
      Classifier._trigger_rehighlight()
    end)
  end
  
  return false
end

---Find a schema by name in a specific database
---Does NOT block - only searches already-loaded schemas
---@param db DbClass The database to search
---@param schema_name string Schema name (case-insensitive)
---@return SchemaClass? schema The schema if found
function Classifier._find_schema(db, schema_name)
  if not db then return nil end
  
  -- Schedule schema load if not already loaded (non-blocking)
  Classifier._ensure_schemas_loaded(db)
  
  -- Only search what's already in memory
  local schemas = db.schemas or {}
  
  local name_lower = schema_name:lower()
  for _, schema in ipairs(schemas) do
    local s_name = schema.schema_name or schema.name
    if s_name and s_name:lower() == name_lower then
      return schema
    end
  end
  return nil
end

---Find a schema by name across all databases in the buffer's connected server
---@param connection table? Connection context with server/database
---@param schema_name string Schema name (case-insensitive)
---@return SchemaClass? schema The schema if found
---@return DbClass? database The database containing the schema
function Classifier._find_schema_in_connection(connection, schema_name)
  if not connection or not connection.database then
    return nil, nil
  end
  
  local db = connection.database
  local schema = Classifier._find_schema(db, schema_name)
  if schema then
    return schema, db
  end
  
  return nil, nil
end

---Ensure a schema's objects are loaded (tables, views, procs, funcs, synonyms)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param schema SchemaClass The schema to load objects for
---@return boolean is_loaded True if schema is already loaded and data is available now
function Classifier._ensure_schema_objects_loaded(schema)
  if not schema then return false end
  
  -- Already loaded - data is available
  if schema.is_loaded then
    return true
  end
  
  -- Not loaded - schedule load for next tick (non-blocking)
  -- First pass will mark as unresolved, but once load completes
  -- the semantic highlighter will re-trigger and apply proper highlights
  if schema.load and not schema._loading_scheduled then
    schema._loading_scheduled = true
    vim.schedule(function()
      schema:load()
      schema._loading_scheduled = false
      -- Re-trigger semantic highlighting after load completes
      Classifier._trigger_rehighlight()
    end)
  end
  
  return false
end

---Ensure a database's objects are loaded (for non-schema servers like MySQL/SQLite)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param db DbClass The database to load objects for
---@return boolean is_loaded True if database is already loaded and data is available now
function Classifier._ensure_db_objects_loaded(db)
  if not db then return false end
  
  -- Already loaded - data is available
  if db.is_loaded then
    return true
  end
  
  -- Not loaded - schedule load for next tick (non-blocking)
  if db.load and not db._loading_scheduled then
    db._loading_scheduled = true
    vim.schedule(function()
      db:load()
      db._loading_scheduled = false
      -- Re-trigger semantic highlighting after load completes
      Classifier._trigger_rehighlight()
    end)
  end
  
  return false
end

---Ensure object details are loaded (columns for tables/views, params for procs/funcs)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param obj table The object (table, view, procedure, function)
---@return boolean is_loaded True if object details are already loaded
function Classifier._ensure_object_details_loaded(obj)
  if not obj then return false end
  
  -- Load columns for tables/views
  if obj.object_type == "table" or obj.object_type == "view" then
    if obj.columns_loaded then
      return true
    end
    if obj.load_columns and not obj._loading_scheduled then
      obj._loading_scheduled = true
      vim.schedule(function()
        obj:load_columns()
        obj._loading_scheduled = false
        Classifier._trigger_rehighlight()
      end)
    end
    return false
    
  -- Load parameters for procedures/functions
  elseif obj.object_type == "procedure" or obj.object_type == "function" then
    if obj.parameters_loaded then
      return true
    end
    if obj.load_parameters and not obj._loading_scheduled then
      obj._loading_scheduled = true
      vim.schedule(function()
        obj:load_parameters()
        obj._loading_scheduled = false
        Classifier._trigger_rehighlight()
      end)
    end
    return false
  end
  
  return true  -- Unknown object type, assume loaded
end

---Trigger a re-highlight of the current buffer
---Called after background loads complete
function Classifier._trigger_rehighlight()
  -- Use vim.schedule to ensure this runs after current highlight cycle
  vim.schedule(function()
    local semantic = require('ssns.highlighting.semantic')
    -- Get current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    -- Check if this buffer has semantic highlighting enabled
    if semantic.is_attached(bufnr) then
      semantic.update(bufnr)
    end
  end)
end

---Find an object (table/view/proc/func/synonym) in a schema
---@param schema SchemaClass The schema to search
---@param name string Object name (case-insensitive)
---@return string? type The object type ("table", "view", etc.)
---@return table? obj The object if found
function Classifier._find_object_in_schema(schema, name)
  if not schema then return nil, nil end
  
  -- Ensure schema objects are loaded
  Classifier._ensure_schema_objects_loaded(schema)
  
  local name_lower = name:lower()
  
  -- Check tables
  for _, tbl in ipairs(schema.tables or {}) do
    local tbl_name = tbl.table_name or tbl.name
    if tbl_name and tbl_name:lower() == name_lower then
      return "table", tbl
    end
  end
  
  -- Check views
  for _, view in ipairs(schema.views or {}) do
    local view_name = view.view_name or view.name
    if view_name and view_name:lower() == name_lower then
      return "view", view
    end
  end
  
  -- Check procedures
  for _, proc in ipairs(schema.procedures or {}) do
    local proc_name = proc.procedure_name or proc.name
    if proc_name and proc_name:lower() == name_lower then
      return "procedure", proc
    end
  end
  
  -- Check functions
  for _, func in ipairs(schema.functions or {}) do
    local func_name = func.function_name or func.name
    if func_name and func_name:lower() == name_lower then
      return "function", func
    end
  end
  
  -- Check synonyms
  for _, syn in ipairs(schema.synonyms or {}) do
    local syn_name = syn.synonym_name or syn.name
    if syn_name and syn_name:lower() == name_lower then
      return "synonym", syn
    end
  end
  
  return nil, nil
end

---Find an object in a database (for non-schema servers like MySQL/SQLite)
---@param db DbClass The database to search
---@param name string Object name (case-insensitive)
---@return string? type The object type
---@return table? obj The object if found
function Classifier._find_object_in_db(db, name)
  if not db then return nil, nil end
  
  -- Ensure database objects are loaded
  Classifier._ensure_db_objects_loaded(db)
  
  local name_lower = name:lower()
  
  -- Check tables
  for _, tbl in ipairs(db.tables or {}) do
    local tbl_name = tbl.table_name or tbl.name
    if tbl_name and tbl_name:lower() == name_lower then
      return "table", tbl
    end
  end
  
  -- Check views
  for _, view in ipairs(db.views or {}) do
    local view_name = view.view_name or view.name
    if view_name and view_name:lower() == name_lower then
      return "view", view
    end
  end
  
  -- Check procedures
  for _, proc in ipairs(db.procedures or {}) do
    local proc_name = proc.procedure_name or proc.name
    if proc_name and proc_name:lower() == name_lower then
      return "procedure", proc
    end
  end
  
  -- Check functions
  for _, func in ipairs(db.functions or {}) do
    local func_name = func.function_name or func.name
    if func_name and func_name:lower() == name_lower then
      return "function", func
    end
  end
  
  -- Check synonyms
  for _, syn in ipairs(db.synonyms or {}) do
    local syn_name = syn.synonym_name or syn.name
    if syn_name and syn_name:lower() == name_lower then
      return "synonym", syn
    end
  end
  
  return nil, nil
end

---Check if a server uses schemas (SQL Server, PostgreSQL) or not (MySQL, SQLite)
---@param db DbClass The database to check
---@return boolean uses_schemas True if the database type uses schemas
function Classifier._db_uses_schemas(db)
  if not db then return false end
  -- Check if db has get_adapter method (may not if it's not a proper DbClass)
  if not db.get_adapter then return false end
  local adapter = db:get_adapter()
  return adapter and adapter.features and adapter.features.schemas
end

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
        if create_object_type then
          in_create_alter = false
          create_object_type = nil
        end

        prev_token = token
        i = i + consumed
        -- Skip adding result since we added directly
        result = nil
      end

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

    else
      -- Other tokens (DOT, COMMA, PAREN, STAR) - skip
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
  local sql_context = Classifier._build_context(chunk)

  -- Get clause position for context-aware disambiguation
  -- This helps when objects aren't loaded yet (FROM → schema.table, SELECT → alias.column)
  local clause = nil
  if chunk and parts[1] then
    local StatementParser = require('ssns.completion.statement_parser')
    clause = StatementParser.get_clause_at_position(chunk, parts[1].line, parts[1].col)
  end

  -- Build resolution context with clause info and CREATE context
  local resolution_context = {
    is_database_context = keyword_context.is_database_context,
    clause = clause,  -- "from", "select", "where", "join", "on", "group_by", "having", "order_by", etc.
    create_object_type = keyword_context.create_object_type,  -- "procedure", "function", etc. in CREATE statements
  }

  -- Resolve each part against the cache, building context as we go
  local resolved_types = Classifier._resolve_multipart_from_cache(names, sql_context, connection, resolution_context)

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

---Scan the UI tree cache for an object by name
---Returns the object type if found: "database", "schema", "table", "view", "procedure", "function"
---NOTE: Uses skip_load=true to prevent triggering database loads during highlighting
---@param name string Object name to search for (case-insensitive)
---@return string? object_type The type if found, nil otherwise
---@return table? object The found object (for database/table/view/etc) or parent database (for schema)
---@return table? parent The parent object
function Classifier._find_in_tree_cache(name)
  local Cache = require('ssns.cache')
  local name_lower = name:lower()
  
  -- Use skip_load to prevent triggering database loads during semantic highlighting
  -- This ensures we only search already-loaded data and don't cause RPC calls
  local skip_opts = { skip_load = true }

  -- Scan all servers using accessor methods
  for _, server in ipairs(Cache.servers or {}) do
    -- Check each database
    for _, db in ipairs(server:get_databases()) do
      local db_name = db.db_name or db.name
      if db_name and db_name:lower() == name_lower then
        return "database", db, server
      end

      -- Check schemas (for schema-based servers)
      for _, schema in ipairs(db:get_schemas()) do
        local schema_name = schema.schema_name or schema.name
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end

      -- Check tables (skip_load prevents triggering load)
      for _, tbl in ipairs(db:get_tables(nil, skip_opts)) do
        local tbl_name = tbl.table_name or tbl.name
        if tbl_name and tbl_name:lower() == name_lower then
          return "table", tbl, db
        end
        -- Also check if name matches a schema_name
        local schema_name = tbl.schema_name or tbl.schema
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end

      -- Check views (skip_load prevents triggering load)
      for _, view in ipairs(db:get_views(nil, skip_opts)) do
        local view_name = view.view_name or view.name
        if view_name and view_name:lower() == name_lower then
          return "view", view, db
        end
        local schema_name = view.schema_name or view.schema
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end

      -- Check procedures (skip_load prevents triggering load)
      for _, proc in ipairs(db:get_procedures(nil, skip_opts)) do
        local proc_name = proc.procedure_name or proc.name
        if proc_name and proc_name:lower() == name_lower then
          return "procedure", proc, db
        end
        local schema_name = proc.schema_name or proc.schema
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end

      -- Check functions (skip_load prevents triggering load)
      for _, func in ipairs(db:get_functions(nil, skip_opts)) do
        local func_name = func.function_name or func.name
        if func_name and func_name:lower() == name_lower then
          return "function", func, db
        end
        local schema_name = func.schema_name or func.schema
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end

      -- Check synonyms (skip_load prevents triggering load)
      for _, syn in ipairs(db:get_synonyms(nil, skip_opts)) do
        local syn_name = syn.synonym_name or syn.name
        if syn_name and syn_name:lower() == name_lower then
          return "synonym", syn, db
        end
        local schema_name = syn.schema_name or syn.schema
        if schema_name and schema_name:lower() == name_lower then
          return "schema", db, server
        end
      end
    end
  end

  return nil, nil, nil
end

---Scan for schema in a specific database (checks schema_name property on tables/views/etc)
---@param db table Database object
---@param name string Schema name
---@return boolean found True if schema exists in this database
function Classifier._find_schema_in_db(db, name)
  local name_lower = name:lower()
  
  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- First check actual schema objects (for schema-based servers)
  for _, schema in ipairs(db:get_schemas()) do
    local schema_name = schema.schema_name or schema.name
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  -- Also check schema_name property on objects (fallback)
  for _, tbl in ipairs(db:get_tables(nil, skip_opts)) do
    local schema_name = tbl.schema_name or tbl.schema
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  for _, view in ipairs(db:get_views(nil, skip_opts)) do
    local schema_name = view.schema_name or view.schema
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  for _, proc in ipairs(db:get_procedures(nil, skip_opts)) do
    local schema_name = proc.schema_name or proc.schema
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  for _, func in ipairs(db:get_functions(nil, skip_opts)) do
    local schema_name = func.schema_name or func.schema
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  for _, syn in ipairs(db:get_synonyms(nil, skip_opts)) do
    local schema_name = syn.schema_name or syn.schema
    if schema_name and schema_name:lower() == name_lower then
      return true
    end
  end

  return false
end

---Scan for table/view in a specific database with optional schema filter
---@param db table Database object
---@param name string Table/view name
---@param schema_name string? Optional schema name to filter by
---@return string? type "table" or "view"
---@return table? object The table/view if found
function Classifier._find_table_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()
  
  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- Search tables using accessor (schema filter handled by accessor)
  for _, tbl in ipairs(db:get_tables(schema_name, skip_opts)) do
    local tbl_name = tbl.table_name or tbl.name
    if tbl_name and tbl_name:lower() == name_lower then
      -- If schema filter provided, verify it matches
      local tbl_schema = tbl.schema_name or tbl.schema
      if not schema_lower or (tbl_schema and tbl_schema:lower() == schema_lower) then
        return "table", tbl
      end
    end
  end

  -- Search views using accessor
  for _, view in ipairs(db:get_views(schema_name, skip_opts)) do
    local view_name = view.view_name or view.name
    if view_name and view_name:lower() == name_lower then
      local view_schema = view.schema_name or view.schema
      if not schema_lower or (view_schema and view_schema:lower() == schema_lower) then
        return "view", view
      end
    end
  end

  return nil, nil
end

---Scan for procedure/function in a specific database with optional schema filter
---@param db table Database object
---@param name string Procedure/function name
---@param schema_name string? Optional schema name to filter by
---@return string? type "procedure" or "function"
---@return table? object The procedure/function if found
function Classifier._find_routine_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()
  
  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- Search procedures using accessor
  for _, proc in ipairs(db:get_procedures(schema_name, skip_opts)) do
    local proc_name = proc.procedure_name or proc.name
    if proc_name and proc_name:lower() == name_lower then
      local proc_schema = proc.schema_name or proc.schema
      if not schema_lower or (proc_schema and proc_schema:lower() == schema_lower) then
        return "procedure", proc
      end
    end
  end

  -- Search functions using accessor
  for _, func in ipairs(db:get_functions(schema_name, skip_opts)) do
    local func_name = func.function_name or func.name
    if func_name and func_name:lower() == name_lower then
      local func_schema = func.schema_name or func.schema
      if not schema_lower or (func_schema and func_schema:lower() == schema_lower) then
        return "function", func
      end
    end
  end

  return nil, nil
end

---Scan for synonym in a specific database with optional schema filter
---@param db table Database object
---@param name string Synonym name
---@param schema_name string? Optional schema name to filter by
---@return table? object The synonym if found
function Classifier._find_synonym_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()
  
  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- Search synonyms using accessor
  for _, syn in ipairs(db:get_synonyms(schema_name, skip_opts)) do
    local syn_name = syn.synonym_name or syn.name
    if syn_name and syn_name:lower() == name_lower then
      local syn_schema = syn.schema_name or syn.schema
      if not schema_lower or (syn_schema and syn_schema:lower() == schema_lower) then
        return syn
      end
    end
  end
  return nil
end

---Check if a column exists in a table/view object
---@param obj table Table or view object
---@param column_name string Column name to find
---@return boolean found True if column exists
function Classifier._find_column_in_object(obj, column_name)
  if not obj or not obj.columns then
    return false
  end

  local name_lower = column_name:lower()

  for _, col in ipairs(obj.columns) do
    local col_name = col.column_name or col.name
    if col_name and col_name:lower() == name_lower then
      return true
    end
  end

  return false
end

---Find a column in tables referenced by the current statement
---This is more efficient than searching the entire database - it only checks
---tables that appear in the FROM/JOIN clauses of the current statement
---@param sql_context table Context with tables from StatementChunk
---@param column_name string Column name to find
---@param connection table? Connection context with server/database
---@return boolean found True if column exists in any context table
function Classifier._find_column_in_context_tables(sql_context, column_name, connection)
  if not sql_context.tables or #sql_context.tables == 0 then
    return false
  end

  local connected_db = connection and connection.database
  if not connected_db then
    return false
  end

  local uses_schemas = Classifier._db_uses_schemas(connected_db)

  for _, table_ref in ipairs(sql_context.tables) do
    -- Skip CTEs, temp tables, and table variables - they don't have loaded columns
    if table_ref.is_cte or table_ref.is_temp or table_ref.is_table_variable then
      goto continue
    end

    local obj = nil
    local table_name = table_ref.name
    local schema_name = table_ref.schema

    if not table_name then
      goto continue
    end

    -- Find the actual table/view object
    if uses_schemas then
      -- If schema specified in reference, search that schema
      if schema_name then
        local schema = Classifier._find_schema(connected_db, schema_name)
        if schema then
          local obj_type
          obj_type, obj = Classifier._find_object_in_schema(schema, table_name)
        end
      else
        -- No schema specified - search default schema first, then all loaded schemas
        local default_schema_name = connected_db:get_default_schema()
        local default_schema = Classifier._find_schema(connected_db, default_schema_name)
        if default_schema then
          local obj_type
          obj_type, obj = Classifier._find_object_in_schema(default_schema, table_name)
        end

        -- If not found in default schema, search all loaded schemas
        if not obj then
          for _, schema in ipairs(connected_db.schemas or {}) do
            if schema.is_loaded then
              local obj_type
              obj_type, obj = Classifier._find_object_in_schema(schema, table_name)
              if obj then break end
            end
          end
        end
      end
    else
      -- Non-schema database (MySQL, SQLite)
      local obj_type
      obj_type, obj = Classifier._find_object_in_db(connected_db, table_name)
    end

    -- Check if column exists in this table/view
    if obj then
      Classifier._ensure_object_details_loaded(obj)
      if Classifier._find_column_in_object(obj, column_name) then
        return true
      end
    end

    ::continue::
  end

  return false
end

---Find a table object from the statement context
---Returns the actual table/view object for a TableReference
---@param table_ref table TableReference from sql_context.tables
---@param connection table? Connection context
---@return table? obj The table/view object if found
---@return string? obj_type The object type ("table" or "view")
function Classifier._resolve_table_ref_to_object(table_ref, connection)
  if not table_ref or not table_ref.name then
    return nil, nil
  end

  -- Skip CTEs, temp tables, table variables
  if table_ref.is_cte or table_ref.is_temp or table_ref.is_table_variable then
    return nil, nil
  end

  local connected_db = connection and connection.database
  if not connected_db then
    return nil, nil
  end

  local uses_schemas = Classifier._db_uses_schemas(connected_db)
  local table_name = table_ref.name
  local schema_name = table_ref.schema

  if uses_schemas then
    if schema_name then
      local schema = Classifier._find_schema(connected_db, schema_name)
      if schema then
        return Classifier._find_object_in_schema(schema, table_name)
      end
    else
      -- Search default schema first
      local default_schema_name = connected_db:get_default_schema()
      local default_schema = Classifier._find_schema(connected_db, default_schema_name)
      if default_schema then
        local obj_type, obj = Classifier._find_object_in_schema(default_schema, table_name)
        if obj then return obj_type, obj end
      end

      -- Search all loaded schemas
      for _, schema in ipairs(connected_db.schemas or {}) do
        if schema.is_loaded then
          local obj_type, obj = Classifier._find_object_in_schema(schema, table_name)
          if obj then return obj_type, obj end
        end
      end
    end
  else
    return Classifier._find_object_in_db(connected_db, table_name)
  end

  return nil, nil
end

---Find all columns across all loaded tables/views in the cache
---@param column_name string Column name to search for
---@return boolean found True if column exists anywhere
function Classifier._find_column_in_cache(column_name)
  local Cache = require('ssns.cache')
  
  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  for _, server in ipairs(Cache.servers or {}) do
    local databases = server:get_databases()
    for _, db in ipairs(databases) do
      -- Check tables (skip_load prevents triggering load)
      local tables = db:get_tables(nil, skip_opts)
      for _, tbl in ipairs(tables) do
        if Classifier._find_column_in_object(tbl, column_name) then
          return true
        end
      end
      -- Check views (skip_load prevents triggering load)
      local views = db:get_views(nil, skip_opts)
      for _, view in ipairs(views) do
        if Classifier._find_column_in_object(view, column_name) then
          return true
        end
      end
    end
  end

  return false
end

---Resolve multi-part identifier using smart loading with proper disambiguation
---
---Resolution priority (designed to match SQL Server interpretation):
---1. 4-part identifiers (linked servers) → mark as unresolved (not tracked)
---2. USE keyword context → always database
---3. Local SQL context (aliases, CTEs, temp tables) → highest priority
---4. Schema in current database (with valid object) → before cross-DB lookup
---5. Cross-database reference (database.schema.object)
---6. Object in current database's default schema
---7. Tables from SQL chunk
---8. Single-part column lookup
---9. Clause-based heuristics when objects aren't loaded
---10. Unresolved fallback
---
---@param names string[] Array of identifier names (without brackets)
---@param sql_context table Context with aliases, CTEs, temp tables
---@param connection table? Connection context with server/database
---@param resolution_context table? Resolution context with is_database_context and clause
---@return string[] types Array of semantic types for each part
function Classifier._resolve_multipart_from_cache(names, sql_context, connection, resolution_context)
  local types = {}
  resolution_context = resolution_context or {}

  if #names == 0 then
    return types
  end

  local name1 = names[1]
  local name1_lower = name1:lower()

  -- ============================================================================
  -- Step 1: 4-part identifiers (linked servers) - mark as unresolved
  -- server.database.schema.table format - we don't track linked servers
  -- ============================================================================
  if #names >= 4 then
    -- Could be database.schema.table.column or server.database.schema.table
    -- Try to disambiguate: if first part is a known database, it's db.schema.table.column
    local db = Classifier._find_database(name1)
    if db then
      -- It's database.schema.table.column
      return Classifier._resolve_as_database_qualified(names, db)
    end
    -- First part is not a database → likely linked server → unresolved
    for i = 1, #names do
      types[i] = "unresolved"
    end
    return types
  end

  -- ============================================================================
  -- Step 2: USE keyword context - first part is always database
  -- ============================================================================
  if resolution_context.is_database_context and #names == 1 then
    local db = Classifier._find_database(name1)
    if db then
      Classifier._ensure_schemas_loaded(db)
    end
    return { "database" }
  end

  -- ============================================================================
  -- Step 2.5: CREATE/ALTER context - highlight object being created/altered
  -- When we're in a CREATE PROCEDURE/FUNCTION statement, highlight the object name
  -- as that type even if it doesn't exist in the cache yet
  -- ============================================================================
  if resolution_context.create_object_type then
    local obj_type = resolution_context.create_object_type  -- "procedure", "function", "view"

    if #names == 1 then
      -- Single identifier: sp_SearchEmployees
      types[1] = obj_type
      return types
    elseif #names == 2 then
      -- Two-part: dbo.sp_SearchEmployees → schema.procedure
      -- First check if first part is a schema
      local connected_db = connection and connection.database
      if connected_db and Classifier._db_uses_schemas(connected_db) then
        local schema = Classifier._find_schema(connected_db, name1)
        if schema then
          types[1] = "schema"
          types[2] = obj_type
          return types
        end
      end
      -- Not a schema - might be database.object or just assume schema.object
      types[1] = "schema"
      types[2] = obj_type
      return types
    elseif #names == 3 then
      -- Three-part: mydb.dbo.sp_SearchEmployees → database.schema.procedure
      types[1] = "database"
      types[2] = "schema"
      types[3] = obj_type
      return types
    end
  end

  -- ============================================================================
  -- Step 3: Local SQL context (aliases, CTEs, temp tables)
  -- These take precedence over database objects
  -- ============================================================================

  -- Check if first part is an alias
  if sql_context.aliases[name1_lower] then
    types[1] = "alias"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Check if first part is a CTE
  if sql_context.ctes[name1_lower] then
    types[1] = "cte"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Check if first part is a temp table
  if name1:match("^#") or sql_context.temp_tables[name1_lower] then
    types[1] = "temp_table"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Get the buffer's connected database for context
  local connected_db = connection and connection.database
  local uses_schemas = connected_db and Classifier._db_uses_schemas(connected_db)

  -- ============================================================================
  -- Step 4: Schema in current database (BEFORE cross-database lookup)
  -- This is the key disambiguation: current DB context takes priority
  -- e.g., if connected to "otherdb" and "mydb" is both a database AND a schema
  -- in otherdb, then mydb.users should be schema.table, not database.table
  -- ============================================================================
  if connected_db and uses_schemas and #names >= 2 then
    local schema = Classifier._find_schema(connected_db, name1)
    if schema then
      -- Verify that the second part exists as an object in this schema
      Classifier._ensure_schema_objects_loaded(schema)
      local obj_type, obj = Classifier._find_object_in_schema(schema, names[2])

      if obj_type then
        -- Confirmed: schema.object in current database
        types[1] = "schema"
        types[2] = obj_type
        Classifier._ensure_object_details_loaded(obj)

        -- Verify remaining parts as columns
        for i = 3, #names do
          if Classifier._find_column_in_object(obj, names[i]) then
            types[i] = "column"
          else
            types[i] = "unresolved"
          end
        end
        return types
      end
      -- Schema exists but object not found/not loaded yet
      -- Don't return here - fall through to check if it could be a database reference
      -- But if schema is loaded and object not found, prefer schema interpretation
      if schema.is_loaded then
        -- Schema is loaded and object doesn't exist → still classify as schema.unresolved
        -- (prefer lowest hierarchy level: schema.table over database.schema)
        types[1] = "schema"
        types[2] = "unresolved"
        for i = 3, #names do
          types[i] = "unresolved"
        end
        return types
      end
    end
  end

  -- ============================================================================
  -- Step 5: Cross-database reference (database.schema.object or database.object)
  -- Only checked AFTER schema in current DB
  -- ============================================================================
  local db = Classifier._find_database(name1)
  if db then
    return Classifier._resolve_as_database_qualified(names, db)
  end

  -- ============================================================================
  -- Step 6: Schema reference without verified object (schema not fully loaded)
  -- If we get here and name1 is a schema in current DB but objects weren't loaded,
  -- use clause-based heuristics
  -- ============================================================================
  if connected_db and uses_schemas and #names >= 2 then
    local schema = Classifier._find_schema(connected_db, name1)
    if schema then
      -- Schema exists but objects not loaded yet
      types[1] = "schema"
      -- Use clause heuristics for second part
      if resolution_context.clause then
        local clause = resolution_context.clause
        if clause == "from" or clause == "join" then
          types[2] = "table"  -- Assume table in FROM/JOIN
        elseif clause == "exec" then
          types[2] = "procedure"
        else
          types[2] = "unresolved"
        end
      else
        types[2] = "unresolved"
      end
      for i = 3, #names do
        types[i] = "column"
      end
      return types
    end
  end

  -- ============================================================================
  -- Step 7: Object in current database (table, view, procedure, etc.)
  -- ============================================================================
  if connected_db then
    local obj_type, obj

    if uses_schemas then
      -- For schema-based DBs, search default schema first
      local default_schema_name = connected_db:get_default_schema()
      local default_schema = Classifier._find_schema(connected_db, default_schema_name)
      if default_schema then
        Classifier._ensure_schema_objects_loaded(default_schema)
        obj_type, obj = Classifier._find_object_in_schema(default_schema, name1)
      end

      -- If not found in default schema, search all loaded schemas
      if not obj_type then
        for _, schema in ipairs(connected_db.schemas or {}) do
          if schema.is_loaded then
            obj_type, obj = Classifier._find_object_in_schema(schema, name1)
            if obj_type then break end
          end
        end
      end
    else
      -- For non-schema DBs (MySQL, SQLite), search directly in database
      Classifier._ensure_db_objects_loaded(connected_db)
      obj_type, obj = Classifier._find_object_in_db(connected_db, name1)
    end

    if obj_type then
      types[1] = obj_type
      Classifier._ensure_object_details_loaded(obj)

      for i = 2, #names do
        if Classifier._find_column_in_object(obj, names[i]) then
          types[i] = "column"
        else
          types[i] = "unresolved"
        end
      end
      return types
    end
  end

  -- ============================================================================
  -- Step 8: Tables from SQL chunk's tables list (with column verification)
  -- Check if first part matches a table referenced in this statement
  -- ============================================================================
  for _, tbl in ipairs(sql_context.tables or {}) do
    local tbl_name = tbl.name or tbl.table
    if tbl_name then
      local simple_name = tbl_name:match("%.([^%.]+)$") or tbl_name
      if simple_name:lower() == name1_lower then
        types[1] = "table"

        -- Try to resolve the table and verify columns
        local obj_type, obj = Classifier._resolve_table_ref_to_object(tbl, connection)
        if obj then
          Classifier._ensure_object_details_loaded(obj)
          for i = 2, #names do
            if Classifier._find_column_in_object(obj, names[i]) then
              types[i] = "column"
            else
              types[i] = "unresolved"
            end
          end
        else
          -- Table not loaded yet - assume remaining parts are columns
          for i = 2, #names do
            types[i] = "column"
          end
        end
        return types
      end
    end
  end

  -- ============================================================================
  -- Step 9: Single-part column lookup (context-aware)
  -- First check columns in tables referenced by this statement (fast path),
  -- then fall back to searching all loaded tables in the database (slow path)
  -- ============================================================================
  if #names == 1 then
    -- Fast path: Check columns in tables from this statement's FROM/JOIN clauses
    -- This is more accurate and efficient than searching the entire database
    if Classifier._find_column_in_context_tables(sql_context, name1, connection) then
      types[1] = "column"
      return types
    end

    -- Slow path: Fall back to searching all loaded tables in the database
    -- This handles cases like subqueries or when tables aren't parsed yet
    if connected_db then
      if Classifier._find_column_in_loaded_objects(connected_db, name1) then
        types[1] = "column"
        return types
      end
    end
  end

  -- ============================================================================
  -- Step 10: Clause-based heuristics for unloaded objects
  -- When we can't verify, use clause position as hint
  -- ============================================================================
  if #names >= 2 and resolution_context.clause then
    local clause = resolution_context.clause

    if #names == 2 then
      if clause == "from" or clause == "join" then
        -- In FROM/JOIN: likely schema.table
        types[1] = "schema"
        types[2] = "table"
        return types
      elseif clause == "select" or clause == "where" or clause == "on" or
             clause == "group_by" or clause == "having" or clause == "order_by" then
        -- In SELECT/WHERE/ON: likely table.column or alias.column
        -- Since we already checked aliases, assume table.column
        types[1] = "table"
        types[2] = "column"
        return types
      elseif clause == "exec" then
        -- In EXEC: likely schema.procedure
        types[1] = "schema"
        types[2] = "procedure"
        return types
      end
    elseif #names == 3 then
      if clause == "from" or clause == "join" then
        -- In FROM/JOIN: likely schema.table.alias (rare) or we already resolved
        types[1] = "schema"
        types[2] = "table"
        types[3] = "column"
        return types
      elseif clause == "select" or clause == "where" or clause == "on" then
        -- In SELECT/WHERE: likely schema.table.column
        types[1] = "schema"
        types[2] = "table"
        types[3] = "column"
        return types
      end
    end
  end

  -- ============================================================================
  -- Step 11: Fallback - mark all as unresolved
  -- ============================================================================
  for i = 1, #names do
    types[i] = "unresolved"
  end

  return types
end

---Helper: Resolve identifier as database-qualified (database.schema.object or database.object)
---@param names string[] Array of identifier names
---@param db DbClass The database object
---@return string[] types Array of semantic types
function Classifier._resolve_as_database_qualified(names, db)
  local types = {}
  types[1] = "database"

  Classifier._ensure_schemas_loaded(db)

  if #names == 1 then
    return types
  end

  if Classifier._db_uses_schemas(db) then
    -- Schema-based database: database.schema.object.column
    local schema = Classifier._find_schema(db, names[2])
    if schema then
      types[2] = "schema"
      Classifier._ensure_schema_objects_loaded(schema)

      if #names >= 3 then
        local obj_type, obj = Classifier._find_object_in_schema(schema, names[3])
        if obj_type then
          types[3] = obj_type
          Classifier._ensure_object_details_loaded(obj)

          for i = 4, #names do
            if Classifier._find_column_in_object(obj, names[i]) then
              types[i] = "column"
            else
              types[i] = "unresolved"
            end
          end
        else
          types[3] = "unresolved"
          for i = 4, #names do
            types[i] = "unresolved"
          end
        end
      end
    else
      types[2] = "unresolved"
      for i = 3, #names do
        types[i] = "unresolved"
      end
    end
  else
    -- Non-schema database: database.object.column
    local obj_type, obj = Classifier._find_object_in_db(db, names[2])
    if obj_type then
      types[2] = obj_type
      Classifier._ensure_object_details_loaded(obj)

      for i = 3, #names do
        if Classifier._find_column_in_object(obj, names[i]) then
          types[i] = "column"
        else
          types[i] = "unresolved"
        end
      end
    else
      types[2] = "unresolved"
      for i = 3, #names do
        types[i] = "unresolved"
      end
    end
  end

  return types
end

---Find a column by name in already-loaded objects of a database
---Does NOT trigger any loading - only searches what's already in memory
---@param db DbClass The database to search
---@param column_name string Column name to find
---@return boolean found True if column found
function Classifier._find_column_in_loaded_objects(db, column_name)
  if not db then return false end
  
  local name_lower = column_name:lower()
  
  -- For schema-based databases
  if Classifier._db_uses_schemas(db) then
    for _, schema in ipairs(db.schemas or {}) do
      if schema.is_loaded then
        -- Search tables
        for _, tbl in ipairs(schema.tables or {}) do
          if tbl.columns then
            for _, col in ipairs(tbl.columns) do
              local col_name = col.column_name or col.name
              if col_name and col_name:lower() == name_lower then
                return true
              end
            end
          end
        end
        -- Search views
        for _, view in ipairs(schema.views or {}) do
          if view.columns then
            for _, col in ipairs(view.columns) do
              local col_name = col.column_name or col.name
              if col_name and col_name:lower() == name_lower then
                return true
              end
            end
          end
        end
      end
    end
  else
    -- For non-schema databases
    if db.is_loaded then
      -- Search tables
      for _, tbl in ipairs(db.tables or {}) do
        if tbl.columns then
          for _, col in ipairs(tbl.columns) do
            local col_name = col.column_name or col.name
            if col_name and col_name:lower() == name_lower then
              return true
            end
          end
        end
      end
      -- Search views
      for _, view in ipairs(db.views or {}) do
        if view.columns then
          for _, col in ipairs(view.columns) do
            local col_name = col.column_name or col.name
            if col_name and col_name:lower() == name_lower then
              return true
            end
          end
        end
      end
    end
  end
  
  return false
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
