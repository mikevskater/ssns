---Resolution functions for the classifier
---Handles cache scanning and multi-part identifier resolution
---@class ClassifierResolvers
local M = {}

-- Import loaders module
local Loaders = require('nvim-ssns.highlighting.classifier_loaders')

---Search a single database for an object by name
---@param db DbClass Database to search
---@param server ServerClass Server containing the database
---@param name_lower string Lowercase object name
---@param skip_opts table Skip load options
---@return string? object_type, table? object, table? parent
local function search_database_for_object(db, server, name_lower, skip_opts)
  -- Check schemas (for schema-based servers)
  for _, schema in ipairs(db:get_schemas(skip_opts)) do
    local schema_name = schema.schema_name or schema.name
    if schema_name and schema_name:lower() == name_lower then
      return "schema", db, server
    end
  end

  -- Check tables
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

  -- Check views
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

  -- Check procedures
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

  -- Check functions
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

  -- Check synonyms
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

  return nil, nil, nil
end

---Scan the UI tree cache for an object by name, prioritizing the connected database
---Returns the object type if found: "database", "schema", "table", "view", "procedure", "function"
---NOTE: Uses skip_load=true to prevent triggering database loads during highlighting
---@param name string Object name to search for (case-insensitive)
---@param connection table? Connection context - searched first if provided
---@return string? object_type The type if found, nil otherwise
---@return table? object The found object (for database/table/view/etc) or parent database (for schema)
---@return table? parent The parent object
function M.find_in_tree_cache(name, connection)
  local Cache = require('nvim-ssns.cache')
  local name_lower = name:lower()

  -- Use skip_load to prevent triggering database loads during semantic highlighting
  local skip_opts = { skip_load = true }

  -- Priority 1: Search the connected database first (most common case)
  if connection and connection.database then
    local db = connection.database
    local server = connection.server

    -- Check if name matches the connected database name
    local db_name = db.db_name or db.name
    if db_name and db_name:lower() == name_lower then
      return "database", db, server
    end

    -- Search within the connected database
    local obj_type, obj, parent = search_database_for_object(db, server, name_lower, skip_opts)
    if obj_type then
      return obj_type, obj, parent
    end
  end

  -- Priority 2: Check if name is a database name on the connected server
  -- (for cross-database queries like "USE OtherDb" or "OtherDb.dbo.Table")
  if connection and connection.server then
    local server = connection.server
    for _, db in ipairs(server:get_databases(skip_opts)) do
      local db_name = db.db_name or db.name
      if db_name and db_name:lower() == name_lower then
        return "database", db, server
      end
    end
  end

  -- Priority 3: If no connection, fall back to scanning all servers (legacy behavior)
  -- This is only used when buffer has no connection context
  if not connection then
    for _, server in ipairs(Cache.servers or {}) do
      for _, db in ipairs(server:get_databases(skip_opts)) do
        local db_name = db.db_name or db.name
        if db_name and db_name:lower() == name_lower then
          return "database", db, server
        end

        local obj_type, obj, parent = search_database_for_object(db, server, name_lower, skip_opts)
        if obj_type then
          return obj_type, obj, parent
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
function M.find_schema_in_db(db, name)
  local name_lower = name:lower()

  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- First check actual schema objects (for schema-based servers, skip_load prevents triggering load)
  for _, schema in ipairs(db:get_schemas(skip_opts)) do
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
function M.find_table_in_db(db, name, schema_name)
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
function M.find_routine_in_db(db, name, schema_name)
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
function M.find_synonym_in_db(db, name, schema_name)
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
function M.find_column_in_object(obj, column_name)
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
function M.find_column_in_context_tables(sql_context, column_name, connection)
  if not sql_context.tables or #sql_context.tables == 0 then
    return false
  end

  local connected_db = connection and connection.database
  if not connected_db then
    return false
  end

  local uses_schemas = Loaders.db_uses_schemas(connected_db)

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
        local schema = Loaders.find_schema(connected_db, schema_name)
        if schema then
          local obj_type
          obj_type, obj = Loaders.find_object_in_schema(schema, table_name)
        end
      else
        -- No schema specified - search default schema first, then all loaded schemas
        local default_schema_name = connected_db:get_default_schema()
        local default_schema = Loaders.find_schema(connected_db, default_schema_name)
        if default_schema then
          local obj_type
          obj_type, obj = Loaders.find_object_in_schema(default_schema, table_name)
        end

        -- If not found in default schema, search all loaded schemas
        if not obj then
          for _, schema in ipairs(connected_db.schemas or {}) do
            if schema.is_loaded then
              local obj_type
              obj_type, obj = Loaders.find_object_in_schema(schema, table_name)
              if obj then break end
            end
          end
        end
      end
    else
      -- Non-schema database (MySQL, SQLite)
      local obj_type
      obj_type, obj = Loaders.find_object_in_db(connected_db, table_name)
    end

    -- Check if column exists in this table/view
    if obj then
      Loaders.ensure_object_details_loaded(obj)
      if M.find_column_in_object(obj, column_name) then
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
function M.resolve_table_ref_to_object(table_ref, connection)
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

  local uses_schemas = Loaders.db_uses_schemas(connected_db)
  local table_name = table_ref.name
  local schema_name = table_ref.schema

  if uses_schemas then
    if schema_name then
      local schema = Loaders.find_schema(connected_db, schema_name)
      if schema then
        return Loaders.find_object_in_schema(schema, table_name)
      end
    else
      -- Search default schema first
      local default_schema_name = connected_db:get_default_schema()
      local default_schema = Loaders.find_schema(connected_db, default_schema_name)
      if default_schema then
        local obj_type, obj = Loaders.find_object_in_schema(default_schema, table_name)
        if obj then return obj_type, obj end
      end

      -- Search all loaded schemas
      for _, schema in ipairs(connected_db.schemas or {}) do
        if schema.is_loaded then
          local obj_type, obj = Loaders.find_object_in_schema(schema, table_name)
          if obj then return obj_type, obj end
        end
      end
    end
  else
    return Loaders.find_object_in_db(connected_db, table_name)
  end

  return nil, nil
end

---Find all columns across loaded tables/views, prioritizing the connected database
---@param column_name string Column name to search for
---@param connection table? Connection context - searched first if provided
---@return boolean found True if column exists anywhere
function M.find_column_in_cache(column_name, connection)
  local Cache = require('nvim-ssns.cache')

  -- Use skip_load to prevent triggering database loads
  local skip_opts = { skip_load = true }

  -- Priority 1: Search the connected database first
  if connection and connection.database then
    local db = connection.database
    -- Check tables
    local tables = db:get_tables(nil, skip_opts)
    for _, tbl in ipairs(tables) do
      if M.find_column_in_object(tbl, column_name) then
        return true
      end
    end
    -- Check views
    local views = db:get_views(nil, skip_opts)
    for _, view in ipairs(views) do
      if M.find_column_in_object(view, column_name) then
        return true
      end
    end
    -- Found in connected database is the common case - don't scan other servers
    return false
  end

  -- Priority 2: No connection - fall back to scanning all servers (legacy behavior)
  if not connection then
    for _, server in ipairs(Cache.servers or {}) do
      local databases = server:get_databases(skip_opts)
      for _, db in ipairs(databases) do
        local tables = db:get_tables(nil, skip_opts)
        for _, tbl in ipairs(tables) do
          if M.find_column_in_object(tbl, column_name) then
            return true
          end
        end
        local views = db:get_views(nil, skip_opts)
        for _, view in ipairs(views) do
          if M.find_column_in_object(view, column_name) then
            return true
          end
        end
      end
    end
  end

  return false
end

---Find a column by name in already-loaded objects of a database
---Does NOT trigger any loading - only searches what's already in memory
---@param db DbClass The database to search
---@param column_name string Column name to find
---@return boolean found True if column found
function M.find_column_in_loaded_objects(db, column_name)
  if not db then return false end

  local name_lower = column_name:lower()

  -- For schema-based databases
  if Loaders.db_uses_schemas(db) then
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

---Resolve multi-part identifier using smart loading with proper disambiguation
---
---Resolution priority (designed to match SQL Server interpretation):
---1. 4-part identifiers (linked servers) -> mark as unresolved (not tracked)
---2. USE keyword context -> always database
---3. Local SQL context (aliases, CTEs, temp tables) -> highest priority
---4. Schema in current database (with valid object) -> before cross-DB lookup
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
function M.resolve_multipart_from_cache(names, sql_context, connection, resolution_context)
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
    local db = Loaders.find_database(name1, connection)
    if db then
      -- It's database.schema.table.column
      return M.resolve_as_database_qualified(names, db)
    end
    -- First part is not a database -> likely linked server -> unresolved
    for i = 1, #names do
      types[i] = "unresolved"
    end
    return types
  end

  -- ============================================================================
  -- Step 2: USE keyword context - first part is always database
  -- ============================================================================
  if resolution_context.is_database_context and #names == 1 then
    local db = Loaders.find_database(name1, connection)
    if db then
      Loaders.ensure_schemas_loaded(db)
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
      -- Two-part: dbo.sp_SearchEmployees -> schema.procedure
      -- First check if first part is a schema
      local connected_db = connection and connection.database
      if connected_db and Loaders.db_uses_schemas(connected_db) then
        local schema = Loaders.find_schema(connected_db, name1)
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
      -- Three-part: mydb.dbo.sp_SearchEmployees -> database.schema.procedure
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
  local uses_schemas = connected_db and Loaders.db_uses_schemas(connected_db)

  -- ============================================================================
  -- Step 4: Schema in current database (BEFORE cross-database lookup)
  -- This is the key disambiguation: current DB context takes priority
  -- e.g., if connected to "otherdb" and "mydb" is both a database AND a schema
  -- in otherdb, then mydb.users should be schema.table, not database.table
  -- ============================================================================
  if connected_db and uses_schemas and #names >= 2 then
    local schema = Loaders.find_schema(connected_db, name1)
    if schema then
      -- Verify that the second part exists as an object in this schema
      Loaders.ensure_schema_objects_loaded(schema)
      local obj_type, obj = Loaders.find_object_in_schema(schema, names[2])

      if obj_type then
        -- Confirmed: schema.object in current database
        types[1] = "schema"
        types[2] = obj_type
        Loaders.ensure_object_details_loaded(obj)

        -- Verify remaining parts as columns
        for i = 3, #names do
          if M.find_column_in_object(obj, names[i]) then
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
        -- Schema is loaded and object doesn't exist -> still classify as schema.unresolved
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
  local db = Loaders.find_database(name1, connection)
  if db then
    return M.resolve_as_database_qualified(names, db)
  end

  -- ============================================================================
  -- Step 6: Schema reference without verified object (schema not fully loaded)
  -- If we get here and name1 is a schema in current DB but objects weren't loaded,
  -- use clause-based heuristics
  -- ============================================================================
  if connected_db and uses_schemas and #names >= 2 then
    local schema = Loaders.find_schema(connected_db, name1)
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
      local default_schema = Loaders.find_schema(connected_db, default_schema_name)
      if default_schema then
        Loaders.ensure_schema_objects_loaded(default_schema)
        obj_type, obj = Loaders.find_object_in_schema(default_schema, name1)
      end

      -- If not found in default schema, search all loaded schemas
      if not obj_type then
        for _, schema in ipairs(connected_db.schemas or {}) do
          if schema.is_loaded then
            obj_type, obj = Loaders.find_object_in_schema(schema, name1)
            if obj_type then break end
          end
        end
      end
    else
      -- For non-schema DBs (MySQL, SQLite), search directly in database
      Loaders.ensure_db_objects_loaded(connected_db)
      obj_type, obj = Loaders.find_object_in_db(connected_db, name1)
    end

    if obj_type then
      types[1] = obj_type
      Loaders.ensure_object_details_loaded(obj)

      for i = 2, #names do
        if M.find_column_in_object(obj, names[i]) then
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
        local obj_type, obj = M.resolve_table_ref_to_object(tbl, connection)
        if obj then
          Loaders.ensure_object_details_loaded(obj)
          for i = 2, #names do
            if M.find_column_in_object(obj, names[i]) then
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
    if M.find_column_in_context_tables(sql_context, name1, connection) then
      types[1] = "column"
      return types
    end

    -- Slow path: Fall back to searching all loaded tables in the database
    -- This handles cases like subqueries or when tables aren't parsed yet
    if connected_db then
      if M.find_column_in_loaded_objects(connected_db, name1) then
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
function M.resolve_as_database_qualified(names, db)
  local types = {}
  types[1] = "database"

  Loaders.ensure_schemas_loaded(db)

  if #names == 1 then
    return types
  end

  if Loaders.db_uses_schemas(db) then
    -- Schema-based database: database.schema.object.column
    local schema = Loaders.find_schema(db, names[2])
    if schema then
      types[2] = "schema"
      Loaders.ensure_schema_objects_loaded(schema)

      if #names >= 3 then
        local obj_type, obj = Loaders.find_object_in_schema(schema, names[3])
        if obj_type then
          types[3] = obj_type
          Loaders.ensure_object_details_loaded(obj)

          for i = 4, #names do
            if M.find_column_in_object(obj, names[i]) then
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
    local obj_type, obj = Loaders.find_object_in_db(db, names[2])
    if obj_type then
      types[2] = obj_type
      Loaders.ensure_object_details_loaded(obj)

      for i = 3, #names do
        if M.find_column_in_object(obj, names[i]) then
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

return M
