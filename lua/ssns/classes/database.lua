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

---Create a database-scoped connection config
---@return ConnectionData connection_config
function DbClass:_get_db_connection_config()
  local server = self:get_server()
  local adapter = self:get_adapter()

  -- SQLite: The file path IS the database, no modification needed
  -- The "main" database name is just SQLite's internal reference
  if adapter.db_type == "sqlite" then
    return server.connection_config
  end

  -- For other databases, modify the connection config to target this database
  local Connections = require('ssns.connections')
  return Connections.with_database(server.connection_config, self.db_name)
end

---Load schemas for this database
---@return SchemaClass[]
function DbClass:_load_schemas()
  local adapter = self:get_adapter()
  local SchemaClass = require('ssns.classes.schema')

  -- Get schemas query
  local query = adapter:get_schemas_query(self.db_name)
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  if server and server.connection_config then
    Connection.invalidate_cache(server.connection_config)
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
    -- Don't set self.schemas for non-schema servers (keep as nil)
    -- This ensures truthy checks like "if self.schemas" work correctly
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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
  local results = adapter:execute(self:_get_db_connection_config(), query)
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

---Bulk load all definitions for views, procedures, functions, and tables in this database
---@return table<string, string> definitions Map of "schema.object_type.name" -> definition
function DbClass:load_all_definitions_bulk()
  local adapter = self:get_adapter()
  local definitions = {}

  -- Load views, procedures, functions definitions (from sys.sql_modules)
  if adapter.get_all_definitions_bulk_query then
    local query = adapter:get_all_definitions_bulk_query(self.db_name, nil)
    local results = adapter:execute(self:_get_db_connection_config(), query)
    if adapter.parse_definitions_bulk then
      local module_defs = adapter:parse_definitions_bulk(results)
      for k, v in pairs(module_defs) do
        definitions[k] = v
      end
    end
  end

  -- Load table definitions (generated CREATE TABLE scripts)
  if adapter.get_all_table_definitions_bulk_query then
    local query = adapter:get_all_table_definitions_bulk_query(self.db_name, nil)
    local results = adapter:execute(self:_get_db_connection_config(), query)
    if adapter.parse_table_definitions_bulk then
      local table_defs = adapter:parse_table_definitions_bulk(results)
      for k, v in pairs(table_defs) do
        definitions[k] = v
      end
    end
  end

  return definitions
end

---Bulk load all metadata (columns for tables/views/TVFs, parameters for procedures/functions)
---@return table<string, string> metadata Map of "schema.object_type.name" -> "col1 type1 col2 type2 ..."
function DbClass:load_all_metadata_bulk()
  local adapter = self:get_adapter()
  local metadata = {}

  -- Load columns for all tables/views and TVF return columns (combined query)
  if adapter.get_all_columns_bulk_query then
    local query = adapter:get_all_columns_bulk_query(self.db_name)
    local results = adapter:execute(self:_get_db_connection_config(), query)
    if adapter.parse_all_columns_bulk then
      local columns_meta = adapter:parse_all_columns_bulk(results)
      for k, v in pairs(columns_meta) do
        metadata[k] = v
      end
    end
  end

  -- Load parameters for all procedures/functions
  -- For TVFs, this appends input parameters to the return columns loaded above
  if adapter.get_all_parameters_bulk_query then
    local query = adapter:get_all_parameters_bulk_query(self.db_name)
    local results = adapter:execute(self:_get_db_connection_config(), query)
    if adapter.parse_all_parameters_bulk then
      local params_meta = adapter:parse_all_parameters_bulk(results)
      for k, v in pairs(params_meta) do
        -- Append parameters to existing metadata (for TVFs that have both columns and params)
        if metadata[k] then
          metadata[k] = metadata[k] .. " " .. v
        else
          metadata[k] = v
        end
      end
    end
  end

  return metadata
end

---Generic method to get objects of a specific type with lazy/eager loading
---Consolidates the common pattern used by get_tables, get_views, etc.
---@param config table Configuration for the object type:
---  field_name: string - Name of field on schema/self (e.g., 'tables')
---  bulk_load_method: string - Method name for bulk loading (e.g., 'load_all_tables_bulk')
---  schema_load_method: string - Method on schema for loading (e.g., 'load_tables')
---  schema_get_method: string - Method on schema for getting (e.g., 'get_tables')
---  direct_load_method: string? - Method for non-schema servers (e.g., '_load_tables_direct')
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? }
---@return table[]
function DbClass:_get_objects_aggregated(config, schema_filter, opts)
  opts = opts or {}

  -- Ensure schemas are loaded (but not objects)
  if not opts.skip_load then
    self:_ensure_schemas_loaded()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    -- Check if ANY schema has this object type loaded
    local any_loaded = false
    for _, schema in ipairs(self.schemas) do
      if schema[config.field_name] ~= nil then
        any_loaded = true
        break
      end
    end

    -- If not loaded yet and not skipping load, check loading mode
    if not any_loaded and not opts.skip_load then
      local Config = require('ssns.config')
      local cfg = Config.get()
      local eager_load = cfg.completion and cfg.completion.eager_load

      if eager_load then
        -- Eager mode: load ALL schemas at once (bulk loading)
        self[config.bulk_load_method](self)
      elseif schema_filter then
        -- Lazy mode with specific schema: load only that schema
        for _, schema in ipairs(self.schemas) do
          if schema.name:lower() == schema_filter:lower() then
            schema[config.schema_load_method](schema)
            break
          end
        end
      else
        -- Lazy mode without schema filter: load only default schema
        local default_schema_name = self:get_default_schema()
        for _, schema in ipairs(self.schemas) do
          if schema.name:lower() == default_schema_name:lower() then
            schema[config.schema_load_method](schema)
            break
          end
        end
      end
    end

    -- Aggregate from schemas
    local all_objects = {}
    local default_schema_name = self:get_default_schema()
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        -- In lazy mode, only allow loading for the target schema
        local Config = require('ssns.config')
        local cfg = Config.get()
        local eager_load = cfg.completion and cfg.completion.eager_load

        local schema_opts = vim.tbl_extend('force', opts, {})
        if not eager_load and not opts.skip_load then
          local is_target_schema = schema_filter and schema.name:lower() == schema_filter:lower()
          local is_default_schema = not schema_filter and schema.name:lower() == default_schema_name:lower()
          if not is_target_schema and not is_default_schema then
            schema_opts.skip_load = true  -- Skip loading non-target schemas
          end
        end

        for _, obj in ipairs(schema[config.schema_get_method](schema, schema_opts)) do
          table.insert(all_objects, obj)
        end
      end
    end
    return all_objects
  end

  -- Non-schema servers: load directly if not loaded yet
  if self[config.field_name] == nil and not opts.skip_load then
    if config.direct_load_method then
      self[config.direct_load_method](self)
    end
  end
  return self[config.field_name] or {}
end

---Get all tables (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when tables haven't been loaded yet
---Supports lazy loading based on config.completion.eager_load setting
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return TableClass[]
function DbClass:get_tables(schema_filter, opts)
  return self:_get_objects_aggregated({
    field_name = 'tables',
    bulk_load_method = 'load_all_tables_bulk',
    schema_load_method = 'load_tables',
    schema_get_method = 'get_tables',
    direct_load_method = '_load_tables_direct',
  }, schema_filter, opts)
end

---Load tables directly for non-schema servers (MySQL, SQLite)
---@return boolean success
function DbClass:_load_tables_direct()
  local adapter = self:get_adapter()
  local query = adapter:get_tables_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_config(), query)
  local table_data_list = adapter:parse_tables(results)

  self.tables = {}
  for _, table_data in ipairs(table_data_list) do
    local tbl = adapter:create_table(self, table_data)
    table.insert(self.tables, tbl)
  end
  return true
end

---Get all views (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when views haven't been loaded yet
---Supports lazy loading based on config.completion.eager_load setting
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return ViewClass[]
function DbClass:get_views(schema_filter, opts)
  return self:_get_objects_aggregated({
    field_name = 'views',
    bulk_load_method = 'load_all_views_bulk',
    schema_load_method = 'load_views',
    schema_get_method = 'get_views',
    direct_load_method = '_load_views_direct',
  }, schema_filter, opts)
end

---Load views directly for non-schema servers (MySQL, SQLite)
---@return boolean success
function DbClass:_load_views_direct()
  local adapter = self:get_adapter()

  if not adapter.features.views then
    self.views = {}
    return true
  end

  local query = adapter:get_views_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_config(), query)
  local view_data_list = adapter:parse_views(results)

  self.views = {}
  for _, view_data in ipairs(view_data_list) do
    local view = adapter:create_view(self, view_data)
    table.insert(self.views, view)
  end
  return true
end

---Get all procedures (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when procedures haven't been loaded yet
---Supports lazy loading based on config.completion.eager_load setting
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return ProcedureClass[]
function DbClass:get_procedures(schema_filter, opts)
  return self:_get_objects_aggregated({
    field_name = 'procedures',
    bulk_load_method = 'load_all_procedures_bulk',
    schema_load_method = 'load_procedures',
    schema_get_method = 'get_procedures',
    direct_load_method = '_load_procedures_direct',
  }, schema_filter, opts)
end

---Load procedures directly for non-schema servers (MySQL)
---@return boolean success
function DbClass:_load_procedures_direct()
  local adapter = self:get_adapter()

  if not adapter.features.procedures then
    self.procedures = {}
    return true
  end

  local query = adapter:get_procedures_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_config(), query)
  local proc_data_list = adapter:parse_procedures(results)

  self.procedures = {}
  for _, proc_data in ipairs(proc_data_list) do
    local proc = adapter:create_procedure(self, proc_data)
    table.insert(self.procedures, proc)
  end
  return true
end

---Get all functions (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when functions haven't been loaded yet
---Supports lazy loading based on config.completion.eager_load setting
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return FunctionClass[]
function DbClass:get_functions(schema_filter, opts)
  return self:_get_objects_aggregated({
    field_name = 'functions',
    bulk_load_method = 'load_all_functions_bulk',
    schema_load_method = 'load_functions',
    schema_get_method = 'get_functions',
    direct_load_method = '_load_functions_direct',
  }, schema_filter, opts)
end

---Load functions directly for non-schema servers (MySQL)
---@return boolean success
function DbClass:_load_functions_direct()
  local adapter = self:get_adapter()

  if not adapter.features.functions then
    self.functions = {}
    return true
  end

  local query = adapter:get_functions_query(self.db_name, nil)
  local results = adapter:execute(self:_get_db_connection_config(), query)
  local func_data_list = adapter:parse_functions(results)

  self.functions = {}
  for _, func_data in ipairs(func_data_list) do
    local func = adapter:create_function(self, func_data)
    table.insert(self.functions, func)
  end
  return true
end

---Get all synonyms (server-type aware - aggregates from schemas if needed)
---Uses bulk loading when synonyms haven't been loaded yet
---Supports lazy loading based on config.completion.eager_load setting
---@param schema_filter string? Optional schema name to filter by
---@param opts table? Options { skip_load: boolean? } - skip_load prevents triggering load
---@return SynonymClass[]
function DbClass:get_synonyms(schema_filter, opts)
  return self:_get_objects_aggregated({
    field_name = 'synonyms',
    bulk_load_method = 'load_all_synonyms_bulk',
    schema_load_method = 'load_synonyms',
    schema_get_method = 'get_synonyms',
    -- No direct_load_method: synonyms are SQL Server-specific (schema-based)
  }, schema_filter, opts)
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

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class DbLoadAsyncOpts : ExecutorOpts
---@field on_complete fun(success: boolean, error: string?)? Completion callback

---Load database structure asynchronously
---@param opts DbLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    local success = self:load()
    return success
  end, {
    name = opts.name or string.format("Loading database %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_complete = opts.on_complete,
  })
end

---@class BulkLoadAsyncOpts : ExecutorOpts
---@field on_complete fun(success: boolean, error: string?)? Completion callback

---Load all tables for all schemas asynchronously
---@param opts BulkLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_tables_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading tables...")
    local success = self:load_all_tables_bulk()
    ctx.report_progress(100, "Tables loaded")
    return success
  end, {
    name = opts.name or string.format("Loading tables for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load all views for all schemas asynchronously
---@param opts BulkLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_views_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading views...")
    local success = self:load_all_views_bulk()
    ctx.report_progress(100, "Views loaded")
    return success
  end, {
    name = opts.name or string.format("Loading views for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load all procedures for all schemas asynchronously
---@param opts BulkLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_procedures_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading procedures...")
    local success = self:load_all_procedures_bulk()
    ctx.report_progress(100, "Procedures loaded")
    return success
  end, {
    name = opts.name or string.format("Loading procedures for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load all functions for all schemas asynchronously
---@param opts BulkLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_functions_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading functions...")
    local success = self:load_all_functions_bulk()
    ctx.report_progress(100, "Functions loaded")
    return success
  end, {
    name = opts.name or string.format("Loading functions for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load all synonyms for all schemas asynchronously
---@param opts BulkLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_synonyms_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading synonyms...")
    local success = self:load_all_synonyms_bulk()
    ctx.report_progress(100, "Synonyms loaded")
    return success
  end, {
    name = opts.name or string.format("Loading synonyms for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---@class DefinitionsAsyncOpts : ExecutorOpts
---@field on_complete fun(definitions: table<string, string>?, error: string?)? Completion callback

---Load all definitions asynchronously
---@param opts DefinitionsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_definitions_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading definitions...")
    local definitions = self:load_all_definitions_bulk()
    ctx.report_progress(100, "Definitions loaded")
    return definitions
  end, {
    name = opts.name or string.format("Loading definitions for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---@class MetadataAsyncOpts : ExecutorOpts
---@field on_complete fun(metadata: table<string, string>?, error: string?)? Completion callback

---Load all metadata asynchronously
---@param opts MetadataAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:load_all_metadata_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading metadata...")
    local metadata = self:load_all_metadata_bulk()
    ctx.report_progress(100, "Metadata loaded")
    return metadata
  end, {
    name = opts.name or string.format("Loading metadata for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---@class GetObjectsAsyncOpts : ExecutorOpts
---@field schema_filter string? Optional schema filter
---@field on_complete fun(objects: table[]?, error: string?)? Completion callback

---Get all tables asynchronously (uses lazy/eager loading based on config)
---This is the preferred method for tree UI - it respects config settings
---@param opts GetObjectsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:get_tables_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading tables...")
    local tables = self:get_tables(opts.schema_filter)
    ctx.report_progress(100, "Tables loaded")
    return tables
  end, {
    name = opts.name or string.format("Loading tables for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Get all views asynchronously (uses lazy/eager loading based on config)
---This is the preferred method for tree UI - it respects config settings
---@param opts GetObjectsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:get_views_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading views...")
    local views = self:get_views(opts.schema_filter)
    ctx.report_progress(100, "Views loaded")
    return views
  end, {
    name = opts.name or string.format("Loading views for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Get all procedures asynchronously (uses lazy/eager loading based on config)
---This is the preferred method for tree UI - it respects config settings
---@param opts GetObjectsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:get_procedures_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading procedures...")
    local procedures = self:get_procedures(opts.schema_filter)
    ctx.report_progress(100, "Procedures loaded")
    return procedures
  end, {
    name = opts.name or string.format("Loading procedures for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Get all functions asynchronously (uses lazy/eager loading based on config)
---This is the preferred method for tree UI - it respects config settings
---@param opts GetObjectsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:get_functions_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading functions...")
    local functions = self:get_functions(opts.schema_filter)
    ctx.report_progress(100, "Functions loaded")
    return functions
  end, {
    name = opts.name or string.format("Loading functions for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Get all synonyms asynchronously (uses lazy/eager loading based on config)
---This is the preferred method for tree UI - it respects config settings
---@param opts GetObjectsAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function DbClass:get_synonyms_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading synonyms...")
    local synonyms = self:get_synonyms(opts.schema_filter)
    ctx.report_progress(100, "Synonyms loaded")
    return synonyms
  end, {
    name = opts.name or string.format("Loading synonyms for %s", self.db_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

-- ============================================================================
-- RPC ASYNC METHODS (Non-blocking)
-- ============================================================================
-- These methods use the async RPC mechanism where queries run in Node.js
-- background and call back when complete. The UI stays fully responsive.

---@class RPCAsyncOpts
---@field on_complete fun(result: any, error: string?)? Completion callback
---@field on_error fun(error: string)? Error callback
---@field timeout_ms number? Timeout in milliseconds (default: 60000)

---Load all tables for all schemas using RPC async (non-blocking)
---UI remains responsive during the query execution
---@param opts RPCAsyncOpts? Options
---@return string callback_id Callback ID for cancellation
function DbClass:load_all_tables_bulk_rpc_async(opts)
  opts = opts or {}

  if not self.schemas then
    if opts.on_complete then opts.on_complete(false, "Not a schema-based server") end
    return "no-op"
  end

  local adapter = self:get_adapter()

  -- Get the bulk query (nil schema = all schemas)
  local query = adapter:get_tables_query(self.db_name, nil)

  -- Execute via RPC async
  return adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
    timeout_ms = opts.timeout_ms or 60000,
    on_complete = function(results, err)
      if err then
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
        return
      end

      -- Parse results using adapter's standard parser
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

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = opts.on_error,
  })
end

---Load all views for all schemas using RPC async (non-blocking)
---@param opts RPCAsyncOpts? Options
---@return string callback_id Callback ID for cancellation
function DbClass:load_all_views_bulk_rpc_async(opts)
  opts = opts or {}

  if not self.schemas then
    if opts.on_complete then opts.on_complete(false, "Not a schema-based server") end
    return "no-op"
  end

  local adapter = self:get_adapter()

  if not adapter.features.views then
    -- Set empty arrays for all schemas
    for _, schema in ipairs(self.schemas) do
      schema:set_views({})
    end
    if opts.on_complete then opts.on_complete(true, nil) end
    return "no-op"
  end

  local query = adapter:get_views_query(self.db_name, nil)

  return adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
    timeout_ms = opts.timeout_ms or 60000,
    on_complete = function(results, err)
      if err then
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
        return
      end

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

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = opts.on_error,
  })
end

---Load all procedures for all schemas using RPC async (non-blocking)
---@param opts RPCAsyncOpts? Options
---@return string callback_id Callback ID for cancellation
function DbClass:load_all_procedures_bulk_rpc_async(opts)
  opts = opts or {}

  if not self.schemas then
    if opts.on_complete then opts.on_complete(false, "Not a schema-based server") end
    return "no-op"
  end

  local adapter = self:get_adapter()

  if not adapter.features.procedures then
    for _, schema in ipairs(self.schemas) do
      schema:set_procedures({})
    end
    if opts.on_complete then opts.on_complete(true, nil) end
    return "no-op"
  end

  local query = adapter:get_procedures_query(self.db_name, nil)

  return adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
    timeout_ms = opts.timeout_ms or 60000,
    on_complete = function(results, err)
      if err then
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
        return
      end

      local proc_data_list = adapter:parse_procedures(results)

      -- Group by schema
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

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = opts.on_error,
  })
end

---Load all functions for all schemas using RPC async (non-blocking)
---@param opts RPCAsyncOpts? Options
---@return string callback_id Callback ID for cancellation
function DbClass:load_all_functions_bulk_rpc_async(opts)
  opts = opts or {}

  if not self.schemas then
    if opts.on_complete then opts.on_complete(false, "Not a schema-based server") end
    return "no-op"
  end

  local adapter = self:get_adapter()

  if not adapter.features.functions then
    for _, schema in ipairs(self.schemas) do
      schema:set_functions({})
    end
    if opts.on_complete then opts.on_complete(true, nil) end
    return "no-op"
  end

  local query = adapter:get_functions_query(self.db_name, nil)

  return adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
    timeout_ms = opts.timeout_ms or 60000,
    on_complete = function(results, err)
      if err then
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
        return
      end

      local func_data_list = adapter:parse_functions(results)

      -- Group by schema
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

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = opts.on_error,
  })
end

---Load all synonyms for all schemas using RPC async (non-blocking)
---@param opts RPCAsyncOpts? Options
---@return string callback_id Callback ID for cancellation
function DbClass:load_all_synonyms_bulk_rpc_async(opts)
  opts = opts or {}

  if not self.schemas then
    if opts.on_complete then opts.on_complete(false, "Not a schema-based server") end
    return "no-op"
  end

  local adapter = self:get_adapter()

  if not adapter.features.synonyms then
    for _, schema in ipairs(self.schemas) do
      schema:set_synonyms({})
    end
    if opts.on_complete then opts.on_complete(true, nil) end
    return "no-op"
  end

  local query = adapter:get_synonyms_query(self.db_name, nil)

  return adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
    timeout_ms = opts.timeout_ms or 60000,
    on_complete = function(results, err)
      if err then
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
        return
      end

      local syn_data_list = adapter:parse_synonyms(results)

      -- Group by schema
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

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = opts.on_error,
  })
end

return DbClass
