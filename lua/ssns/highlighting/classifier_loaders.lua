---Smart loading helpers for the classifier
---These functions ensure data is loaded on-demand as the classifier encounters
---references in the SQL buffer. This provides semantic highlighting without
---loading all databases upfront.
---@class ClassifierLoaders
local M = {}

---Find a database by name, prioritizing the connected server
---Only searches already-loaded data - does NOT trigger server connections or loading
---@param name string Database name (case-insensitive)
---@param connection table? Connection context with server/database - searched first if provided
---@return DbClass? database The database if found
---@return ServerClass? server The server containing the database
function M.find_database(name, connection)
  local Cache = require('ssns.cache')
  local name_lower = name:lower()

  -- Use skip_load = true to prevent triggering server connections during semantic highlighting
  local skip_opts = { skip_load = true }

  -- Priority 1: Search the connected server first (most common case)
  if connection and connection.server then
    local server = connection.server
    for _, db in ipairs(server:get_databases(skip_opts)) do
      local db_name = db.db_name or db.name
      if db_name and db_name:lower() == name_lower then
        return db, server
      end
    end
    -- Database not on connected server - this is likely a cross-database reference
    -- Fall through to search other servers only for explicit cross-DB queries
  end

  -- Priority 2: Only scan other servers if this looks like a cross-database reference
  -- (i.e., we have a connection but the database name doesn't match the connected one)
  -- Skip this expensive scan if we don't have a connection context at all
  if connection and connection.server then
    -- We already searched the connected server above
    -- Only search other servers for cross-database references
    for _, server in ipairs(Cache.servers or {}) do
      -- Skip the connected server (already searched)
      if server ~= connection.server then
        for _, db in ipairs(server:get_databases(skip_opts)) do
          local db_name = db.db_name or db.name
          if db_name and db_name:lower() == name_lower then
            return db, server
          end
        end
      end
    end
  elseif not connection then
    -- No connection context - search all servers (legacy fallback)
    for _, server in ipairs(Cache.servers or {}) do
      for _, db in ipairs(server:get_databases(skip_opts)) do
        local db_name = db.db_name or db.name
        if db_name and db_name:lower() == name_lower then
          return db, server
        end
      end
    end
  end

  return nil, nil
end

---Trigger a re-highlight of the current buffer
---Called after background loads complete
function M.trigger_rehighlight()
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

---Ensure a database's schemas are loaded (for schema-based servers)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param db DbClass The database to ensure schemas for
---@return boolean is_loaded True if schemas are already loaded and available now
function M.ensure_schemas_loaded(db)
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
      M.trigger_rehighlight()
    end)
  end

  return false
end

---Find a schema by name in a specific database
---Does NOT block - only searches already-loaded schemas
---@param db DbClass The database to search
---@param schema_name string Schema name (case-insensitive)
---@return SchemaClass? schema The schema if found
function M.find_schema(db, schema_name)
  if not db then return nil end

  -- Schedule schema load if not already loaded (non-blocking)
  M.ensure_schemas_loaded(db)

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
function M.find_schema_in_connection(connection, schema_name)
  if not connection or not connection.database then
    return nil, nil
  end

  local db = connection.database
  local schema = M.find_schema(db, schema_name)
  if schema then
    return schema, db
  end

  return nil, nil
end

---Ensure a schema's objects are loaded (tables, views, procs, funcs, synonyms)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param schema SchemaClass The schema to load objects for
---@return boolean is_loaded True if schema is already loaded and data is available now
function M.ensure_schema_objects_loaded(schema)
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
      M.trigger_rehighlight()
    end)
  end

  return false
end

---Ensure a database's objects are loaded (for non-schema servers like MySQL/SQLite)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param db DbClass The database to load objects for
---@return boolean is_loaded True if database is already loaded and data is available now
function M.ensure_db_objects_loaded(db)
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
      M.trigger_rehighlight()
    end)
  end

  return false
end

---Ensure object details are loaded (columns for tables/views, params for procs/funcs)
---This is NON-BLOCKING: If not loaded, schedules a load for next tick
---@param obj table The object (table, view, procedure, function)
---@return boolean is_loaded True if object details are already loaded
function M.ensure_object_details_loaded(obj)
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
        M.trigger_rehighlight()
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
        M.trigger_rehighlight()
      end)
    end
    return false
  end

  return true  -- Unknown object type, assume loaded
end

---Find an object (table/view/proc/func/synonym) in a schema
---@param schema SchemaClass The schema to search
---@param name string Object name (case-insensitive)
---@return string? type The object type ("table", "view", etc.)
---@return table? obj The object if found
function M.find_object_in_schema(schema, name)
  if not schema then return nil, nil end

  -- Ensure schema objects are loaded
  M.ensure_schema_objects_loaded(schema)

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
function M.find_object_in_db(db, name)
  if not db then return nil, nil end

  -- Ensure database objects are loaded
  M.ensure_db_objects_loaded(db)

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
function M.db_uses_schemas(db)
  if not db then return false end
  -- Check if db has get_adapter method (may not if it's not a proper DbClass)
  if not db.get_adapter then return false end
  local adapter = db:get_adapter()
  return adapter and adapter.features and adapter.features.schemas
end

return M
