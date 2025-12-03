local BaseDbObject = require('ssns.classes.base')

---@class DbClass : BaseDbObject
---@field db_name string The database name
---@field parent ServerClass The parent server object
---@field schemas SchemaClass[]? Array of schema objects (for schema-based servers like SQL Server/PostgreSQL)
---@field tables TableClass[]? Array of table objects (for non-schema servers like MySQL)
---@field views ViewClass[]? Array of view objects (for non-schema servers like MySQL)
---@field procedures ProcedureClass[]? Array of procedure objects (for non-schema servers like MySQL)
---@field functions FunctionClass[]? Array of function objects (for non-schema servers like MySQL)
---@field synonyms SynonymClass[]? Array of synonym objects (for non-schema servers)
---@field is_connected boolean Whether this database is the active connection
local DbClass = setmetatable({}, { __index = BaseDbObject })
DbClass.__index = DbClass

---Create a new Database instance
---@param opts {name: string, parent: ServerClass}
---@return DbClass
function DbClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), DbClass)

  self.object_type = "database"
  self.db_name = opts.name

  -- Typed arrays - which are populated depends on server type
  self.schemas = nil     -- For schema-based servers (SQL Server, PostgreSQL)
  self.tables = nil      -- For non-schema servers (MySQL)
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil

  self.is_connected = false

  return self
end

---Load database structure (lazy - doesn't load all objects)
---For schema-based servers (SQL Server, PostgreSQL): loads schema names only
---For non-schema servers (MySQL): loads objects directly on database
---@return boolean success
function DbClass:load()
  if self.is_loaded then
    return true
  end

  local adapter = self:get_adapter()

  -- Check if this is a schema-based server
  if adapter.features.schemas then
    -- SQL Server/PostgreSQL: Load schema names only (lazy loading of objects)
    self.schemas = self:_load_schemas()
    -- NOTE: Don't call schema:load() here - objects are loaded lazily when requested
  else
    -- MySQL/SQLite: Load objects directly on database
    self.tables = self:_load_tables()
    self.views = self:_load_views()
    self.procedures = self:_load_procedures()
    self.functions = self:_load_functions()
    -- Non-schema servers typically don't have synonyms
  end

  self.is_loaded = true
  return true
end

---Create a database-scoped connection string
---@return string connection_string
function DbClass:_get_db_connection_string()
  local server = self:get_server()
  local adapter = self:get_adapter()

  -- SQLite: The file path IS the database, no modification needed
  -- The "main" database name is just SQLite's internal reference
  if adapter.db_type == "sqlite" then
    return server.connection_string
  end

  -- For other databases, modify the connection string to target this database
  local ConnectionString = require('ssns.connection_string')
  return ConnectionString.with_database(server.connection_string, self.db_name)
end

---Load schemas for this database
---@return SchemaClass[]
function DbClass:_load_schemas()
  local adapter = self:get_adapter()
  local SchemaClass = require('ssns.classes.schema')

  -- Get schemas query
  local query = adapter:get_schemas_query(self.db_name)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local schema_data_list = adapter:parse_schemas(results)

  local schemas = {}
  for _, schema_data in ipairs(schema_data_list) do
    local schema = SchemaClass.new({
      name = schema_data.name,
      parent = self,
    })
    table.insert(schemas, schema)
  end

  return schemas
end

---Load tables directly (for non-schema servers)
---@return TableClass[]
function DbClass:_load_tables()
  local adapter = self:get_adapter()

  local query = adapter:get_tables_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local table_data_list = adapter:parse_tables(results)

  local tables = {}
  for _, table_data in ipairs(table_data_list) do
    local table_obj = adapter:create_table(nil, table_data)
    table_obj.parent = self
    table.insert(tables, table_obj)
  end

  return tables
end

---Load views directly (for non-schema servers)
---@return ViewClass[]
function DbClass:_load_views()
  local adapter = self:get_adapter()

  if not adapter.features.views then
    return {}
  end

  local query = adapter:get_views_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local view_data_list = adapter:parse_views(results)

  local views = {}
  for _, view_data in ipairs(view_data_list) do
    local view_obj = adapter:create_view(nil, view_data)
    view_obj.parent = self
    table.insert(views, view_obj)
  end

  return views
end

---Load procedures directly (for non-schema servers)
---@return ProcedureClass[]
function DbClass:_load_procedures()
  local adapter = self:get_adapter()

  if not adapter.features.procedures then
    return {}
  end

  local query = adapter:get_procedures_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local proc_data_list = adapter:parse_procedures(results)

  local procedures = {}
  for _, proc_data in ipairs(proc_data_list) do
    local proc_obj = adapter:create_procedure(nil, proc_data)
    proc_obj.parent = self
    table.insert(procedures, proc_obj)
  end

  return procedures
end

---Load functions directly (for non-schema servers)
---@return FunctionClass[]
function DbClass:_load_functions()
  local adapter = self:get_adapter()

  if not adapter.features.functions then
    return {}
  end

  local query = adapter:get_functions_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local func_data_list = adapter:parse_functions(results)

  local functions = {}
  for _, func_data in ipairs(func_data_list) do
    local func_obj = adapter:create_function(nil, func_data)
    func_obj.parent = self
    table.insert(functions, func_obj)
  end

  return functions
end

---Reload objects from database
---@return boolean success
function DbClass:reload()
  -- Invalidate query cache for this database's server connection
  local Connection = require('ssns.connection')
  local server = self:get_server()
  if server and server.connection_string then
    Connection.invalidate_cache(server.connection_string)
  end

  -- Clear typed arrays
  self.schemas = nil
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil
  self.is_loaded = false
  return self:load()
end

---Find a schema by name
---@param schema_name string
---@return SchemaClass?
function DbClass:find_schema(schema_name)
  if not self.is_loaded then
    self:load()
  end

  -- Search schemas array directly (case-insensitive)
  local lower_name = schema_name:lower()
  for _, schema in ipairs(self.schemas or {}) do
    if schema.name:lower() == lower_name then
      return schema
    end
  end

  return nil
end

---Get all schemas
---@return SchemaClass[]
function DbClass:get_schemas()
  -- For schema completion, only load schema names (not all objects)
  if not self.schemas then
    self:_ensure_schemas_loaded()
  end
  return self.schemas or {}
end

---Ensure schemas are loaded (for schema-based servers)
---This is a lightweight loader that ONLY loads schema names, not objects
---@return boolean success
function DbClass:_ensure_schemas_loaded()
  if self.schemas then
    return true  -- Already loaded
  end

  local adapter = self:get_adapter()
  
  if not adapter.features.schemas then
    self.schemas = {}
    return false  -- Not a schema-based server
  end

  -- Load schema names only
  self.schemas = self:_load_schemas()
  return true
end

---Load all tables for all schemas in a single bulk query
---Distributes results to appropriate schema objects
---Only works for schema-based servers
---@return boolean success
function DbClass:load_all_tables_bulk()
  if not self.schemas then
    return false  -- Only for schema-based servers
  end

  local adapter = self:get_adapter()
  
  -- Execute single bulk query (adapter already updated to return all tables)
  local query = adapter:get_tables_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local table_data_list = adapter:parse_tables(results)

  -- Group tables by schema
  local tables_by_schema = {}
  for _, table_data in ipairs(table_data_list) do
    local schema_name = table_data.schema
    if not tables_by_schema[schema_name] then
      tables_by_schema[schema_name] = {}
    end
    table.insert(tables_by_schema[schema_name], table_data)
  end

  -- Distribute to schemas
  for _, schema in ipairs(self.schemas) do
    local schema_tables = tables_by_schema[schema.name] or {}
    schema:set_tables(schema_tables)
  end

  return true
end

---Load all views for all schemas in a single bulk query
---Distributes results to appropriate schema objects
---Only works for schema-based servers
---@return boolean success
function DbClass:load_all_views_bulk()
  if not self.schemas then
    return false  -- Only for schema-based servers
  end

  local adapter = self:get_adapter()
  
  if not adapter.features.views then
    -- Set empty arrays for all schemas
    for _, schema in ipairs(self.schemas) do
      schema:set_views({})
    end
    return true
  end

  -- Execute single bulk query
  local query = adapter:get_views_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local view_data_list = adapter:parse_views(results)

  -- Group views by schema
  local views_by_schema = {}
  for _, view_data in ipairs(view_data_list) do
    local schema_name = view_data.schema
    if not views_by_schema[schema_name] then
      views_by_schema[schema_name] = {}
    end
    table.insert(views_by_schema[schema_name], view_data)
  end

  -- Distribute to schemas
  for _, schema in ipairs(self.schemas) do
    local schema_views = views_by_schema[schema.name] or {}
    schema:set_views(schema_views)
  end

  return true
end

---Load all procedures for all schemas in a single bulk query
---Distributes results to appropriate schema objects
---Only works for schema-based servers
---@return boolean success
function DbClass:load_all_procedures_bulk()
  if not self.schemas then
    return false  -- Only for schema-based servers
  end

  local adapter = self:get_adapter()
  
  if not adapter.features.procedures then
    -- Set empty arrays for all schemas
    for _, schema in ipairs(self.schemas) do
      schema:set_procedures({})
    end
    return true
  end

  -- Execute single bulk query
  local query = adapter:get_procedures_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local proc_data_list = adapter:parse_procedures(results)

  -- Group procedures by schema
  local procs_by_schema = {}
  for _, proc_data in ipairs(proc_data_list) do
    local schema_name = proc_data.schema
    if not procs_by_schema[schema_name] then
      procs_by_schema[schema_name] = {}
    end
    table.insert(procs_by_schema[schema_name], proc_data)
  end

  -- Distribute to schemas
  for _, schema in ipairs(self.schemas) do
    local schema_procs = procs_by_schema[schema.name] or {}
    schema:set_procedures(schema_procs)
  end

  return true
end

---Load all functions for all schemas in a single bulk query
---Distributes results to appropriate schema objects
---Only works for schema-based servers
---@return boolean success
function DbClass:load_all_functions_bulk()
  if not self.schemas then
    return false  -- Only for schema-based servers
  end

  local adapter = self:get_adapter()
  
  if not adapter.features.functions then
    -- Set empty arrays for all schemas
    for _, schema in ipairs(self.schemas) do
      schema:set_functions({})
    end
    return true
  end

  -- Execute single bulk query
  local query = adapter:get_functions_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local func_data_list = adapter:parse_functions(results)

  -- Group functions by schema
  local funcs_by_schema = {}
  for _, func_data in ipairs(func_data_list) do
    local schema_name = func_data.schema
    if not funcs_by_schema[schema_name] then
      funcs_by_schema[schema_name] = {}
    end
    table.insert(funcs_by_schema[schema_name], func_data)
  end

  -- Distribute to schemas
  for _, schema in ipairs(self.schemas) do
    local schema_funcs = funcs_by_schema[schema.name] or {}
    schema:set_functions(schema_funcs)
  end

  return true
end

---Load all synonyms for all schemas in a single bulk query
---Distributes results to appropriate schema objects
---Only works for schema-based servers
---@return boolean success
function DbClass:load_all_synonyms_bulk()
  if not self.schemas then
    return false  -- Only for schema-based servers
  end

  local adapter = self:get_adapter()
  
  if not adapter.features.synonyms then
    -- Set empty arrays for all schemas
    for _, schema in ipairs(self.schemas) do
      schema:set_synonyms({})
    end
    return true
  end

  -- Execute single bulk query
  local query = adapter:get_synonyms_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_string(), query)
  local syn_data_list = adapter:parse_synonyms(results)

  -- Group synonyms by schema
  local syns_by_schema = {}
  for _, syn_data in ipairs(syn_data_list) do
    local schema_name = syn_data.schema
    if not syns_by_schema[schema_name] then
      syns_by_schema[schema_name] = {}
    end
    table.insert(syns_by_schema[schema_name], syn_data)
  end

  -- Distribute to schemas
  for _, schema in ipairs(self.schemas) do
    local schema_syns = syns_by_schema[schema.name] or {}
    schema:set_synonyms(schema_syns)
  end

  return true
end

---Get all tables (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when tables haven't been loaded yet
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return TableClass[]
function DbClass:get_tables(schema_filter, opts)
  opts = opts or {}
  
  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has tables loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema.tables ~= nil then
        any_loaded = true
        break
      end
    end

    -- If no schemas have tables loaded yet and not skipping load, use bulk loading
    if not any_loaded and not opts.skip_load then
      self:load_all_tables_bulk()
    end

    -- Aggregate from schemas
    local all_tables = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, t in ipairs(schema:get_tables(opts)) do
          table.insert(all_tables, t)
        end
      end
    end
    return all_tables
  end

  -- Non-schema servers: return direct array
  return self.tables or {}
end

---Get all views (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when views haven't been loaded yet
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return ViewClass[]
function DbClass:get_views(schema_filter, opts)
  opts = opts or {}
  
  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has views loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema.views ~= nil then
        any_loaded = true
        break
      end
    end

    -- If no schemas have views loaded yet and not skipping load, use bulk loading
    if not any_loaded and not opts.skip_load then
      self:load_all_views_bulk()
    end

    -- Aggregate from schemas
    local all_views = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, v in ipairs(schema:get_views(opts)) do
          table.insert(all_views, v)
        end
      end
    end
    return all_views
  end

  -- Non-schema servers: return direct array
  return self.views or {}
end

---Get all procedures (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when procedures haven't been loaded yet
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return ProcedureClass[]
function DbClass:get_procedures(schema_filter, opts)
  opts = opts or {}
  
  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has procedures loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema.procedures ~= nil then
        any_loaded = true
        break
      end
    end

    -- If no schemas have procedures loaded yet and not skipping load, use bulk loading
    if not any_loaded and not opts.skip_load then
      self:load_all_procedures_bulk()
    end

    -- Aggregate from schemas
    local all_procedures = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, p in ipairs(schema:get_procedures(opts)) do
          table.insert(all_procedures, p)
        end
      end
    end
    return all_procedures
  end

  -- Non-schema servers: return direct array
  return self.procedures or {}
end

---Get all functions (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when functions haven't been loaded yet
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return FunctionClass[]
function DbClass:get_functions(schema_filter, opts)
  opts = opts or {}
  
  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has functions loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema.functions ~= nil then
        any_loaded = true
        break
      end
    end

    -- If no schemas have functions loaded yet and not skipping load, use bulk loading
    if not any_loaded and not opts.skip_load then
      self:load_all_functions_bulk()
    end

    -- Aggregate from schemas
    local all_functions = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, f in ipairs(schema:get_functions(opts)) do
          table.insert(all_functions, f)
        end
      end
    end
    return all_functions
  end

  -- Non-schema servers: return direct array
  return self.functions or {}
end

---Get all synonyms (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when synonyms haven't been loaded yet
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return SynonymClass[]
function DbClass:get_synonyms(schema_filter, opts)
  opts = opts or {}
  
  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has synonyms loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema.synonyms ~= nil then
        any_loaded = true
        break
      end
    end

    -- If no schemas have synonyms loaded yet and not skipping load, use bulk loading
    if not any_loaded and not opts.skip_load then
      self:load_all_synonyms_bulk()
    end

    -- Aggregate from schemas
    local all_synonyms = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, s in ipairs(schema:get_synonyms(opts)) do
          table.insert(all_synonyms, s)
        end
      end
    end
    return all_synonyms
  end

  -- Non-schema servers: return direct array (usually empty)
  return self.synonyms or {}
end

---Get the default schema for this database type
---@return string default_schema
function DbClass:get_default_schema()
  local adapter = self:get_adapter()

  if not adapter.features.schemas then
    -- No schema concept - return database name
    return self.db_name
  end

  -- Database-specific defaults
  if adapter.db_type == "sqlserver" then
    return "dbo"
  elseif adapter.db_type == "postgres" then
    return "public"
  elseif adapter.db_type == "mysql" then
    return self.db_name
  elseif adapter.db_type == "sqlite" then
    return "main"
  end

  return "dbo"  -- Fallback
end

---Connect to this database (make it the active database)
function DbClass:connect()
  -- Disconnect all other databases on this server
  local server = self:get_server()
  for _, db in ipairs(server:get_databases()) do
    if db ~= self then
      db.is_connected = false
    end
  end

  self.is_connected = true
end

---Disconnect from this database
function DbClass:disconnect()
  self.is_connected = false
end

---Toggle connection to this database
function DbClass:toggle_connection()
  if self.is_connected then
    self:disconnect()
  else
    self:connect()
  end
end

---Get connection status indicator for UI
---@return string status_icon "✓" for connected, "" for disconnected
function DbClass:get_status_icon()
  return self.is_connected and "✓" or ""
end

---Get display name with connection status
---@return string
function DbClass:get_display_name()
  local status = self:get_status_icon()
  if status ~= "" then
    return string.format("%s %s", self.name, status)
  end
  return self.name
end

---Get the full database path for qualified names
---@return string
function DbClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:quote_identifier(self.db_name)
end

---Get string representation for debugging
---@return string
function DbClass:to_string()
  local count = 0
  if self.schemas then
    count = #self.schemas
  elseif self.tables then
    count = #self.tables
  end
  return string.format(
    "DbClass{name=%s, objects=%d, connected=%s}",
    self.name,
    count,
    tostring(self.is_connected)
  )
end

return DbClass
