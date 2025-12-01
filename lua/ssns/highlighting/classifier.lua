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
  synonym = "SsnsSynonym",
  column = "SsnsColumn",
  alias = "SsnsAlias",
  cte = "SsnsTable",      -- CTEs use table color
  temp_table = "SsnsTable", -- Temp tables use table color
  operator = "SsnsOperator",
  string = "SsnsString",
  number = "SsnsNumber",
  unresolved = "SsnsUnresolved",
}

-- Keywords that indicate the next identifier is a database name
local DATABASE_CONTEXT_KEYWORDS = {
  USE = true,
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

  -- Gather multi-part identifiers (sequences of IDENTIFIER/BRACKET_ID separated by DOT)
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local result = nil

    if token.type == TOKEN_TYPES.KEYWORD or token.type == TOKEN_TYPES.GO then
      -- SQL keyword
      local keyword_upper = token.text:upper()
      last_keyword = keyword_upper

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

      -- Build keyword context (only for USE database detection)
      local keyword_context = {
        is_database_context = last_keyword and DATABASE_CONTEXT_KEYWORDS[last_keyword],
      }

      -- Classify each part by resolving against cache
      local part_results = Classifier._classify_multipart(parts, chunk, connection, config, keyword_context)
      for _, part_result in ipairs(part_results) do
        table.insert(classified, part_result)
      end

      -- Reset last_keyword after consuming identifier
      last_keyword = nil

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

    elseif token.type == TOKEN_TYPES.SEMICOLON then
      -- Semicolon resets keyword context (new statement)
      last_keyword = nil
      i = i + 1

    else
      -- Other tokens (DOT, COMMA, PAREN, STAR) - skip
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

  -- Resolve each part against the cache, building context as we go
  local resolved_types = Classifier._resolve_multipart_from_cache(names, sql_context, connection, keyword_context)

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

---Resolve multi-part identifier using smart loading
---Loads data on-demand based on what's referenced in the SQL:
--- - Database name found → load that database's schemas
--- - Schema name found → load that schema's objects  
--- - Object name found → load that object's details (columns, params)
---@param names string[] Array of identifier names (without brackets)
---@param sql_context table Context with aliases, CTEs, temp tables
---@param connection table? Connection context with server/database
---@param keyword_context table? Keyword context
---@return string[] types Array of semantic types for each part
function Classifier._resolve_multipart_from_cache(names, sql_context, connection, keyword_context)
  local types = {}
  keyword_context = keyword_context or {}

  if #names == 0 then
    return types
  end

  local name1 = names[1]
  local name1_lower = name1:lower()

  -- Special case: after USE keyword, first part is always database
  if keyword_context.is_database_context and #names == 1 then
    -- Smart load: ensure database's schemas are loaded when referenced
    local db = Classifier._find_database(name1)
    if db then
      Classifier._ensure_schemas_loaded(db)
    end
    return { "database" }
  end

  -- Check local SQL context first (aliases, CTEs, temp tables)
  -- These take precedence over database objects

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

  -- Try to resolve based on number of parts and database type
  -- Pattern matching for: Database.Schema.Object.Column, Schema.Object.Column, Object.Column, etc.

  -- First, check if name1 is a database
  local db, server = Classifier._find_database(name1)
  if db then
    types[1] = "database"
    -- Smart load: ensure this database's schemas are loaded
    Classifier._ensure_schemas_loaded(db)

    if #names >= 2 then
      -- Look for schema in this database
      local schema = Classifier._find_schema(db, names[2])
      if schema then
        types[2] = "schema"
        -- Smart load: ensure this schema's objects are loaded
        Classifier._ensure_schema_objects_loaded(schema)

        if #names >= 3 then
          -- Look for object in this schema
          local obj_type, obj = Classifier._find_object_in_schema(schema, names[3])
          if obj_type then
            types[3] = obj_type
            -- Smart load: ensure object details are loaded for column verification
            Classifier._ensure_object_details_loaded(obj)

            -- Verify columns
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
        -- For non-schema databases, second part might be an object directly
        if not Classifier._db_uses_schemas(db) then
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
        else
          types[2] = "unresolved"
          for i = 3, #names do
            types[i] = "unresolved"
          end
        end
      end
    end
    return types
  end

  -- Not a database - check if it's a schema in the connected database
  if connected_db and uses_schemas then
    local schema = Classifier._find_schema(connected_db, name1)
    if schema then
      types[1] = "schema"
      -- Smart load: ensure this schema's objects are loaded
      Classifier._ensure_schema_objects_loaded(schema)

      if #names >= 2 then
        -- Look for object in this schema
        local obj_type, obj = Classifier._find_object_in_schema(schema, names[2])
        if obj_type then
          types[2] = obj_type
          Classifier._ensure_object_details_loaded(obj)

          -- Verify columns
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
  end

  -- Not a schema - check if it's an object in the connected database
  if connected_db then
    local obj_type, obj
    
    if uses_schemas then
      -- For schema-based DBs, search default schema (dbo for SQL Server, public for PostgreSQL)
      local default_schema_name = connected_db:get_default_schema()
      local default_schema = Classifier._find_schema(connected_db, default_schema_name)
      if default_schema then
        Classifier._ensure_schema_objects_loaded(default_schema)
        obj_type, obj = Classifier._find_object_in_schema(default_schema, name1)
      end
      
      -- If not found in default schema, search all loaded schemas (non-blocking)
      if not obj_type then
        -- Use internal array directly to avoid blocking
        for _, schema in ipairs(connected_db.schemas or {}) do
          if schema.is_loaded then  -- Only search already-loaded schemas
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

      -- Verify columns
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

  -- Check if first part is a table from the SQL chunk's tables list
  for _, tbl in ipairs(sql_context.tables or {}) do
    local tbl_name = tbl.name or tbl.table
    if tbl_name then
      local simple_name = tbl_name:match("%.([^%.]+)$") or tbl_name
      if simple_name:lower() == name1_lower then
        types[1] = "table"
        for i = 2, #names do
          types[i] = "column"
        end
        return types
      end
    end
  end

  -- Check if first part is a column name in any loaded object
  if #names == 1 and connected_db then
    if Classifier._find_column_in_loaded_objects(connected_db, name1) then
      types[1] = "column"
      return types
    end
  end

  -- Nothing matched - mark all as unresolved
  for i = 1, #names do
    types[i] = "unresolved"
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

return Classifier
