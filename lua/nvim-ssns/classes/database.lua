local BaseDbObject = require('nvim-ssns.classes.base')

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

  -- Bulk loading flags - prevent redundant queries across all schemas
  self._bulk_columns_loaded = false     -- Columns loaded via bulk query for all schemas
  self._bulk_parameters_loaded = false  -- Parameters loaded via bulk query for all schemas
  self._bulk_definitions_loaded = false -- Definitions loaded via bulk query for all schemas

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
  local Connections = require('nvim-ssns.connections')
  return Connections.with_database(server.connection_config, self.db_name)
end

---Load schemas for this database
---@return SchemaClass[]
function DbClass:_load_schemas()
  local adapter = self:get_adapter()
  local SchemaClass = require('nvim-ssns.classes.schema')

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
  local Connection = require('nvim-ssns.connection')
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
---@param opts { skip_load: boolean? }? Options
---@return SchemaClass[]
function DbClass:get_schemas(opts)
  opts = opts or {}
  -- For schema completion, only load schema names (not all objects)
  if not self.schemas and not opts.skip_load then
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
---This method does double duty:
---  1. Returns definitions map for object search (backward compatible)
---  2. ALSO populates actual objects (Table/View/Procedure/Function definitions)
---     so tree UI and search share the same cache
---@return table<string, string> definitions Map of "schema.object_type.name" -> definition
function DbClass:load_all_definitions_bulk()
  -- Check if already loaded
  if self._bulk_definitions_loaded then
    -- Return cached definitions map if we have it
    return self._bulk_definitions_cache or {}
  end

  local adapter = self:get_adapter()
  local definitions = {}

  -- Load views, procedures, functions definitions (from sys.sql_modules)
  if adapter.get_all_definitions_bulk_query then
    local query = adapter:get_all_definitions_bulk_query(self.db_name, nil)
    local results = adapter:execute(self:_get_db_connection_config(), query)

    -- Parse into definitions map (for backward compatibility)
    if adapter.parse_definitions_bulk then
      local module_defs = adapter:parse_definitions_bulk(results)
      for k, v in pairs(module_defs) do
        definitions[k] = v
      end
    end

    -- ALSO populate actual objects with definitions
    self:_populate_module_definitions_from_bulk_results(results)
  end

  -- Load table definitions (generated CREATE TABLE scripts)
  if adapter.get_all_table_definitions_bulk_query then
    local query = adapter:get_all_table_definitions_bulk_query(self.db_name, nil)
    local results = adapter:execute(self:_get_db_connection_config(), query)

    -- Parse into definitions map (for backward compatibility)
    if adapter.parse_table_definitions_bulk then
      local table_defs = adapter:parse_table_definitions_bulk(results)
      for k, v in pairs(table_defs) do
        definitions[k] = v
      end
    end

    -- ALSO populate actual table objects with definitions
    self:_populate_table_definitions_from_bulk_results(results)
  end

  -- Cache results
  self._bulk_definitions_loaded = true
  self._bulk_definitions_cache = definitions

  return definitions
end

---Populate view/procedure/function definitions from bulk query results
---@param results table Raw query results from get_all_definitions_bulk_query
---@private
function DbClass:_populate_module_definitions_from_bulk_results(results)
  if not results or not results.success then
    return
  end

  local rows = {}
  if results.resultSets and #results.resultSets > 0 then
    rows = results.resultSets[1].rows or {}
  elseif results.rows then
    rows = results.rows
  end

  if #rows == 0 then
    return
  end

  -- Determine default schema for adapters that don't include schema_name in results
  -- MySQL uses "dbo", SQLite uses "main"
  local adapter = self:get_adapter()
  local default_schema
  if adapter.adapter_type == "sqlite" then
    default_schema = "main"
  elseif adapter.adapter_type == "mysql" then
    default_schema = "dbo"
  end

  -- Group definitions by schema.type.name
  -- SQL Server/Postgres have schema_name, MySQL/SQLite don't
  local defs_by_object = {}
  for _, row in ipairs(rows) do
    local schema_name = row.schema_name or default_schema
    local object_name = row.object_name
    local object_type = row.object_type
    local definition = row.definition

    if schema_name and object_name and object_type and definition then
      -- Normalize line endings
      definition = definition:gsub('\r', '')
      local key = string.format("%s.%s.%s", schema_name, object_type, object_name)
      defs_by_object[key] = definition
    end
  end

  -- Now distribute to actual objects
  -- For schema-based servers, iterate schemas
  if self.schemas then
    for _, schema in ipairs(self.schemas) do
      -- Views
      for _, view in ipairs(schema.views or {}) do
        if not view.definition_loaded then
          local key = string.format("%s.view.%s", schema.schema_name, view.view_name)
          local def = defs_by_object[key]
          if def then
            view.definition = def
            view.definition_loaded = true
          end
        end
      end

      -- Procedures
      for _, proc in ipairs(schema.procedures or {}) do
        if not proc.definition_loaded then
          local key = string.format("%s.procedure.%s", schema.schema_name, proc.procedure_name or proc.name)
          local def = defs_by_object[key]
          if def then
            proc.definition = def
            proc.definition_loaded = true
          end
        end
      end

      -- Functions
      for _, func in ipairs(schema.functions or {}) do
        if not func.definition_loaded then
          local key = string.format("%s.function.%s", schema.schema_name, func.function_name or func.name)
          local def = defs_by_object[key]
          if def then
            func.definition = def
            func.definition_loaded = true
          end
        end
      end
    end
  else
    -- Non-schema servers (MySQL, SQLite) - objects directly on database
    local lookup_schema = default_schema or "dbo"

    -- Views
    for _, view in ipairs(self.views or {}) do
      if not view.definition_loaded then
        local key = string.format("%s.view.%s", lookup_schema, view.view_name or view.name)
        local def = defs_by_object[key]
        if def then
          view.definition = def
          view.definition_loaded = true
        end
      end
    end

    -- Procedures
    for _, proc in ipairs(self.procedures or {}) do
      if not proc.definition_loaded then
        local key = string.format("%s.procedure.%s", lookup_schema, proc.procedure_name or proc.name)
        local def = defs_by_object[key]
        if def then
          proc.definition = def
          proc.definition_loaded = true
        end
      end
    end

    -- Functions
    for _, func in ipairs(self.functions or {}) do
      if not func.definition_loaded then
        local key = string.format("%s.function.%s", lookup_schema, func.function_name or func.name)
        local def = defs_by_object[key]
        if def then
          func.definition = def
          func.definition_loaded = true
        end
      end
    end
  end
end

---Populate table definitions from bulk query results
---@param results table Raw query results from get_all_table_definitions_bulk_query
---@private
function DbClass:_populate_table_definitions_from_bulk_results(results)
  if not results or not results.success then
    return
  end

  local rows = {}
  if results.resultSets and #results.resultSets > 0 then
    rows = results.resultSets[1].rows or {}
  elseif results.rows then
    rows = results.rows
  end

  if #rows == 0 then
    return
  end

  -- Determine default schema for adapters that don't include schema_name in results
  -- MySQL uses "dbo", SQLite uses "main"
  local adapter = self:get_adapter()
  local default_schema
  if adapter.adapter_type == "sqlite" then
    default_schema = "main"
  elseif adapter.adapter_type == "mysql" then
    default_schema = "dbo"
  end

  -- Group definitions by schema.table.name
  -- SQL Server/Postgres have schema_name, MySQL/SQLite don't
  local defs_by_table = {}
  for _, row in ipairs(rows) do
    local schema_name = row.schema_name or default_schema
    local table_name = row.table_name
    local definition = row.definition

    if schema_name and table_name and definition then
      -- Normalize line endings
      definition = definition:gsub('\r', '')
      local key = string.format("%s.table.%s", schema_name, table_name)
      defs_by_table[key] = definition
    end
  end

  -- Now distribute to actual objects
  -- For schema-based servers, iterate schemas
  if self.schemas then
    for _, schema in ipairs(self.schemas) do
      for _, tbl in ipairs(schema.tables or {}) do
        if not tbl.definition_loaded then
          local key = string.format("%s.table.%s", schema.schema_name, tbl.table_name)
          local def = defs_by_table[key]
          if def then
            tbl.definition = def
            tbl.definition_loaded = true
          end
        end
      end
    end
  else
    -- Non-schema servers (MySQL, SQLite) - objects directly on database
    local lookup_schema = default_schema or "dbo"

    for _, tbl in ipairs(self.tables or {}) do
      if not tbl.definition_loaded then
        local key = string.format("%s.table.%s", lookup_schema, tbl.table_name or tbl.name)
        local def = defs_by_table[key]
        if def then
          tbl.definition = def
          tbl.definition_loaded = true
        end
      end
    end
  end
end

---Bulk load all metadata (columns for tables/views/TVFs, parameters for procedures/functions)
---This method does double duty:
---  1. Returns search text map for object search (backward compatible)
---  2. ALSO populates actual objects (Table/View/Function columns, Procedure/Function parameters)
---     so tree UI and search share the same cache
---@return table<string, string> metadata Map of "schema.object_type.name" -> "col1 type1 col2 type2 ..."
function DbClass:load_all_metadata_bulk()
  -- Check if already loaded
  if self._bulk_columns_loaded then
    -- Return cached search text map if we have it
    return self._bulk_metadata_cache or {}
  end

  local adapter = self:get_adapter()
  local metadata = {}

  -- Load columns for all tables/views and TVF return columns (combined query)
  if adapter.get_all_columns_bulk_query then
    local query = adapter:get_all_columns_bulk_query(self.db_name)
    local results = adapter:execute(self:_get_db_connection_config(), query)

    -- Parse into search text map (for backward compatibility)
    if adapter.parse_all_columns_bulk then
      local columns_meta = adapter:parse_all_columns_bulk(results)
      for k, v in pairs(columns_meta) do
        metadata[k] = v
      end
    end

    -- ALSO populate actual objects with ColumnClass instances
    self:_populate_columns_from_bulk_results(adapter, results)
  end

  -- Load parameters for all procedures/functions
  -- For TVFs, this appends input parameters to the return columns loaded above
  if adapter.get_all_parameters_bulk_query then
    local query = adapter:get_all_parameters_bulk_query(self.db_name)
    local results = adapter:execute(self:_get_db_connection_config(), query)

    -- Parse into search text map (for backward compatibility)
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

    -- ALSO populate actual objects with ParameterClass instances
    self:_populate_parameters_from_bulk_results(adapter, results)
  end

  -- Cache results
  self._bulk_columns_loaded = true
  self._bulk_metadata_cache = metadata

  return metadata
end

---Populate table/view/function columns from bulk query results
---@param adapter BaseAdapter The database adapter
---@param results table Raw query results from get_all_columns_bulk_query
---@private
function DbClass:_populate_columns_from_bulk_results(adapter, results)
  if not results or not results.success then
    return
  end

  local rows = {}
  if results.resultSets and #results.resultSets > 0 then
    rows = results.resultSets[1].rows or {}
  elseif results.rows then
    rows = results.rows
  end

  if #rows == 0 then
    return
  end

  -- Determine default schema for adapters that don't include schema_name in results
  -- MySQL uses "dbo", SQLite uses "main"
  local default_schema
  if adapter.adapter_type == "sqlite" then
    default_schema = "main"
  elseif adapter.adapter_type == "mysql" then
    default_schema = "dbo"
  end

  -- Group columns by schema.type.name
  -- SQL Server/Postgres have schema_name, MySQL/SQLite don't
  local columns_by_object = {}
  for _, row in ipairs(rows) do
    local schema_name = row.schema_name or default_schema
    local object_name = row.table_name
    local object_type = row.object_type or "table"
    local column_name = row.column_name
    local data_type = row.data_type

    if schema_name and object_name and column_name then
      local key = string.format("%s.%s.%s", schema_name, object_type, object_name)
      if not columns_by_object[key] then
        columns_by_object[key] = {}
      end
      table.insert(columns_by_object[key], {
        name = column_name,
        column_name = column_name,
        data_type = data_type,
        ordinal_position = #columns_by_object[key] + 1,
      })
    end
  end

  -- Now distribute to actual objects
  -- For schema-based servers, iterate schemas
  if self.schemas then
    for _, schema in ipairs(self.schemas) do
      -- Tables
      for _, tbl in ipairs(schema.tables or {}) do
        if not tbl.columns_loaded then
          local key = string.format("%s.table.%s", schema.schema_name, tbl.table_name)
          local col_data_list = columns_by_object[key]
          if col_data_list then
            tbl.columns = {}
            for _, col_data in ipairs(col_data_list) do
              local col_obj = adapter:create_column(nil, col_data)
              table.insert(tbl.columns, col_obj)
            end
            tbl.columns_loaded = true
          end
        end
      end

      -- Views
      for _, view in ipairs(schema.views or {}) do
        if not view.columns_loaded then
          local key = string.format("%s.view.%s", schema.schema_name, view.view_name)
          local col_data_list = columns_by_object[key]
          if col_data_list then
            view.columns = {}
            for _, col_data in ipairs(col_data_list) do
              local col_obj = adapter:create_column(nil, col_data)
              table.insert(view.columns, col_obj)
            end
            view.columns_loaded = true
          end
        end
      end

      -- Functions (TVFs have columns)
      for _, func in ipairs(schema.functions or {}) do
        if not func.columns_loaded then
          local key = string.format("%s.function.%s", schema.schema_name, func.function_name)
          local col_data_list = columns_by_object[key]
          if col_data_list then
            func.columns = {}
            for _, col_data in ipairs(col_data_list) do
              local col_obj = adapter:create_column(nil, col_data)
              table.insert(func.columns, col_obj)
            end
            func.columns_loaded = true
          end
        end
      end
    end
  else
    -- Non-schema servers (MySQL, SQLite) - objects are directly on database
    -- Use the same default_schema that was used when grouping
    local lookup_schema = default_schema or "dbo"

    -- Tables
    for _, tbl in ipairs(self.tables or {}) do
      if not tbl.columns_loaded then
        local key = string.format("%s.table.%s", lookup_schema, tbl.table_name or tbl.name)
        local col_data_list = columns_by_object[key]
        if col_data_list then
          tbl.columns = {}
          for _, col_data in ipairs(col_data_list) do
            local col_obj = adapter:create_column(nil, col_data)
            table.insert(tbl.columns, col_obj)
          end
          tbl.columns_loaded = true
        end
      end
    end

    -- Views
    for _, view in ipairs(self.views or {}) do
      if not view.columns_loaded then
        local key = string.format("%s.view.%s", lookup_schema, view.view_name or view.name)
        local col_data_list = columns_by_object[key]
        if col_data_list then
          view.columns = {}
          for _, col_data in ipairs(col_data_list) do
            local col_obj = adapter:create_column(nil, col_data)
            table.insert(view.columns, col_obj)
          end
          view.columns_loaded = true
        end
      end
    end

    -- Functions (TVFs)
    for _, func in ipairs(self.functions or {}) do
      if not func.columns_loaded then
        local key = string.format("%s.function.%s", lookup_schema, func.function_name or func.name)
        local col_data_list = columns_by_object[key]
        if col_data_list then
          func.columns = {}
          for _, col_data in ipairs(col_data_list) do
            local col_obj = adapter:create_column(nil, col_data)
            table.insert(func.columns, col_obj)
          end
          func.columns_loaded = true
        end
      end
    end
  end
end

---Populate procedure/function parameters from bulk query results
---@param adapter BaseAdapter The database adapter
---@param results table Raw query results from get_all_parameters_bulk_query
---@private
function DbClass:_populate_parameters_from_bulk_results(adapter, results)
  if not results or not results.success then
    return
  end

  local rows = {}
  if results.resultSets and #results.resultSets > 0 then
    rows = results.resultSets[1].rows or {}
  elseif results.rows then
    rows = results.rows
  end

  if #rows == 0 then
    return
  end

  -- Determine default schema for adapters that don't include schema_name in results
  -- MySQL uses "dbo", SQLite uses "main"
  local default_schema
  if adapter.adapter_type == "sqlite" then
    default_schema = "main"
  elseif adapter.adapter_type == "mysql" then
    default_schema = "dbo"
  end

  -- Group parameters by schema.type.name
  -- SQL Server/Postgres have schema_name, MySQL/SQLite don't
  local params_by_object = {}
  for _, row in ipairs(rows) do
    local schema_name = row.schema_name or default_schema
    local object_name = row.routine_name
    local object_type = row.object_type or "function"
    local param_name = row.parameter_name
    local data_type = row.data_type

    if schema_name and object_name and param_name then
      local key = string.format("%s.%s.%s", schema_name, object_type, object_name)
      if not params_by_object[key] then
        params_by_object[key] = {}
      end
      table.insert(params_by_object[key], {
        name = param_name,
        parameter_name = param_name,
        data_type = data_type,
        ordinal_position = #params_by_object[key] + 1,
      })
    end
  end

  local ParameterClass = require('nvim-ssns.classes.parameter')

  -- Now distribute to actual objects
  -- For schema-based servers, iterate schemas
  if self.schemas then
    for _, schema in ipairs(self.schemas) do
      -- Procedures
      for _, proc in ipairs(schema.procedures or {}) do
        if not proc.parameters_loaded then
          local key = string.format("%s.procedure.%s", schema.schema_name, proc.procedure_name or proc.name)
          local param_data_list = params_by_object[key]
          if param_data_list then
            proc.parameters = {}
            for _, param_data in ipairs(param_data_list) do
              local param_obj = ParameterClass.new({
                name = param_data.name,
                data_type = param_data.data_type,
              })
              table.insert(proc.parameters, param_obj)
            end
            proc.parameters_loaded = true
          end
        end
      end

      -- Functions
      for _, func in ipairs(schema.functions or {}) do
        if not func.parameters_loaded then
          local key = string.format("%s.function.%s", schema.schema_name, func.function_name or func.name)
          local param_data_list = params_by_object[key]
          if param_data_list then
            func.parameters = {}
            for _, param_data in ipairs(param_data_list) do
              local param_obj = ParameterClass.new({
                name = param_data.name,
                data_type = param_data.data_type,
              })
              table.insert(func.parameters, param_obj)
            end
            func.parameters_loaded = true
          end
        end
      end
    end
  else
    -- Non-schema servers - objects directly on database
    -- Use the same default_schema that was used when grouping
    local lookup_schema = default_schema or "dbo"

    -- Procedures
    for _, proc in ipairs(self.procedures or {}) do
      if not proc.parameters_loaded then
        local key = string.format("%s.procedure.%s", lookup_schema, proc.procedure_name or proc.name)
        local param_data_list = params_by_object[key]
        if param_data_list then
          proc.parameters = {}
          for _, param_data in ipairs(param_data_list) do
            local param_obj = ParameterClass.new({
              name = param_data.name,
              data_type = param_data.data_type,
            })
            table.insert(proc.parameters, param_obj)
          end
          proc.parameters_loaded = true
        end
      end
    end

    -- Functions
    for _, func in ipairs(self.functions or {}) do
      if not func.parameters_loaded then
        local key = string.format("%s.function.%s", lookup_schema, func.function_name or func.name)
        local param_data_list = params_by_object[key]
        if param_data_list then
          func.parameters = {}
          for _, param_data in ipairs(param_data_list) do
            local param_obj = ParameterClass.new({
              name = param_data.name,
              data_type = param_data.data_type,
            })
            table.insert(func.parameters, param_obj)
          end
          func.parameters_loaded = true
        end
      end
    end
  end

  -- Mark parameters as bulk loaded
  self._bulk_parameters_loaded = true
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
      local Config = require('nvim-ssns.config')
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
        local Config = require('nvim-ssns.config')
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
---@param callback fun(success: boolean, error: string?)? Optional callback when complete
function DbClass:toggle_connection(callback)
  if self.is_connected then
    self:disconnect()
  else
    self:connect()
  end
  -- Database toggle is synchronous (just sets active state), call callback immediately
  if callback then
    vim.schedule(function()
      callback(true, nil)
    end)
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

---@class DbRPCAsyncOpts
---@field timeout_ms number? Timeout in milliseconds (default: 30000)
---@field on_complete fun(success: boolean, error: string?)? Completion callback

---Load database structure using true non-blocking RPC async
---For schema-based servers (SQL Server, PostgreSQL): loads schema names only
---For non-schema servers (MySQL, SQLite): loads objects directly
---This method does NOT block the UI - the query runs in Node.js
---@param opts DbRPCAsyncOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function DbClass:load_async(opts)
  opts = opts or {}
  local Connection = require('nvim-ssns.connection')

  -- Already loaded - return immediately via callback
  if self.is_loaded then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(true, nil)
      end)
    end
    return "already_loaded"
  end

  local adapter = self:get_adapter()
  local db_self = self  -- Capture self for callback

  -- Check if this is a schema-based server
  if adapter.features.schemas then
    -- SQL Server/PostgreSQL: Load schema names only (lazy loading of objects)
    local query = adapter:get_schemas_query(self.db_name)

    return Connection.execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 30000,
      on_complete = function(result, err)
        if err then
          if opts.on_complete then
            opts.on_complete(false, err)
          end
          return
        end

        if not result or not result.success then
          local error_msg = (result and result.error and result.error.message) or "Failed to load schemas"
          if opts.on_complete then
            opts.on_complete(false, error_msg)
          end
          return
        end

        -- Parse schemas from result
        local schema_data_list = adapter:parse_schemas(result)
        local SchemaClass = require('nvim-ssns.classes.schema')

        db_self.schemas = {}
        for _, schema_data in ipairs(schema_data_list) do
          local schema = SchemaClass.new({
            name = schema_data.name,
            parent = db_self,
          })
          table.insert(db_self.schemas, schema)
        end

        db_self.is_loaded = true

        if opts.on_complete then
          opts.on_complete(true, nil)
        end
      end,
    })
  else
    -- MySQL/SQLite: Load objects directly on database
    -- For non-schema servers, we need to load tables (primary use case)
    -- Other objects (views, procedures, functions) can be loaded lazily
    local query = adapter:get_tables_query(self.db_name, nil)

    return Connection.execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 30000,
      on_complete = function(result, err)
        if err then
          if opts.on_complete then
            opts.on_complete(false, err)
          end
          return
        end

        if not result or not result.success then
          local error_msg = (result and result.error and result.error.message) or "Failed to load tables"
          if opts.on_complete then
            opts.on_complete(false, error_msg)
          end
          return
        end

        -- Parse tables from result
        local table_data_list = adapter:parse_tables(result)

        db_self.tables = {}
        for _, table_data in ipairs(table_data_list) do
          local table_obj = adapter:create_table(nil, table_data)
          table_obj.parent = db_self
          table.insert(db_self.tables, table_obj)
        end

        -- Initialize other arrays as empty (will be loaded lazily)
        db_self.views = db_self.views or {}
        db_self.procedures = db_self.procedures or {}
        db_self.functions = db_self.functions or {}

        db_self.is_loaded = true

        if opts.on_complete then
          opts.on_complete(true, nil)
        end
      end,
    })
  end
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
function DbClass:load_tables_async(opts)
  opts = opts or {}

  local adapter = self:get_adapter()
  local db_self = self  -- Capture for callback

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

      if db_self.schemas then
        -- Schema-based servers: distribute to schemas
        local tables_by_schema = {}
        for _, table_data in ipairs(table_data_list) do
          local schema_name = table_data.schema
          if not tables_by_schema[schema_name] then
            tables_by_schema[schema_name] = {}
          end
          table.insert(tables_by_schema[schema_name], table_data)
        end

        for _, schema in ipairs(db_self.schemas) do
          local schema_tables = tables_by_schema[schema.name] or {}
          schema:set_tables(schema_tables)
        end
      else
        -- Non-schema servers (MySQL, SQLite): load directly on database
        db_self.tables = {}
        for _, table_data in ipairs(table_data_list) do
          local tbl = adapter:create_table(db_self, table_data)
          table.insert(db_self.tables, tbl)
        end
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
function DbClass:load_views_async(opts)
  opts = opts or {}

  local adapter = self:get_adapter()
  local db_self = self  -- Capture for callback

  if not adapter.features.views then
    -- Set empty arrays
    if self.schemas then
      for _, schema in ipairs(self.schemas) do
        schema:set_views({})
      end
    else
      self.views = {}
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

      if db_self.schemas then
        -- Schema-based servers: distribute to schemas
        local views_by_schema = {}
        for _, view_data in ipairs(view_data_list) do
          local schema_name = view_data.schema
          if not views_by_schema[schema_name] then
            views_by_schema[schema_name] = {}
          end
          table.insert(views_by_schema[schema_name], view_data)
        end

        for _, schema in ipairs(db_self.schemas) do
          local schema_views = views_by_schema[schema.name] or {}
          schema:set_views(schema_views)
        end
      else
        -- Non-schema servers (MySQL, SQLite): load directly on database
        db_self.views = {}
        for _, view_data in ipairs(view_data_list) do
          local view = adapter:create_view(db_self, view_data)
          table.insert(db_self.views, view)
        end
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
function DbClass:load_procedures_async(opts)
  opts = opts or {}

  local adapter = self:get_adapter()
  local db_self = self  -- Capture for callback

  if not adapter.features.procedures then
    -- Set empty arrays
    if self.schemas then
      for _, schema in ipairs(self.schemas) do
        schema:set_procedures({})
      end
    else
      self.procedures = {}
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

      if db_self.schemas then
        -- Schema-based servers: distribute to schemas
        local procs_by_schema = {}
        for _, proc_data in ipairs(proc_data_list) do
          local schema_name = proc_data.schema
          if not procs_by_schema[schema_name] then
            procs_by_schema[schema_name] = {}
          end
          table.insert(procs_by_schema[schema_name], proc_data)
        end

        for _, schema in ipairs(db_self.schemas) do
          local schema_procs = procs_by_schema[schema.name] or {}
          schema:set_procedures(schema_procs)
        end
      else
        -- Non-schema servers (MySQL, SQLite): load directly on database
        db_self.procedures = {}
        for _, proc_data in ipairs(proc_data_list) do
          local proc = adapter:create_procedure(db_self, proc_data)
          table.insert(db_self.procedures, proc)
        end
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
function DbClass:load_functions_async(opts)
  opts = opts or {}

  local adapter = self:get_adapter()
  local db_self = self  -- Capture for callback

  if not adapter.features.functions then
    -- Set empty arrays
    if self.schemas then
      for _, schema in ipairs(self.schemas) do
        schema:set_functions({})
      end
    else
      self.functions = {}
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

      if db_self.schemas then
        -- Schema-based servers: distribute to schemas
        local funcs_by_schema = {}
        for _, func_data in ipairs(func_data_list) do
          local schema_name = func_data.schema
          if not funcs_by_schema[schema_name] then
            funcs_by_schema[schema_name] = {}
          end
          table.insert(funcs_by_schema[schema_name], func_data)
        end

        for _, schema in ipairs(db_self.schemas) do
          local schema_funcs = funcs_by_schema[schema.name] or {}
          schema:set_functions(schema_funcs)
        end
      else
        -- Non-schema servers (MySQL, SQLite): load directly on database
        db_self.functions = {}
        for _, func_data in ipairs(func_data_list) do
          local func = adapter:create_function(db_self, func_data)
          table.insert(db_self.functions, func)
        end
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
function DbClass:load_synonyms_async(opts)
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

---Load all metadata (columns/parameters) for all objects in bulk asynchronously
---Returns a map of "schema.object" -> "metadata text" (column names, types, etc.)
---Queries run sequentially to avoid overloading the server
---Results are cached - subsequent calls return cached data without querying
---This method does double duty:
---  1. Returns search text map for object search (backward compatible)
---  2. ALSO populates actual objects (Table/View/Function columns, Procedure/Function parameters)
---     so tree UI and search share the same cache
---@param opts { on_complete: fun(metadata: table<string,string>?, err: string?)?, on_error: fun(err: string)?, timeout_ms: number?, force_reload: boolean? }?
---@return string task_id
function DbClass:load_all_metadata_bulk_async(opts)
  opts = opts or {}

  -- Return cached data if already loaded (unless force_reload requested)
  if self._bulk_columns_loaded and self._bulk_metadata_cache and not opts.force_reload then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(self._bulk_metadata_cache, nil)
      end)
    end
    return "cached"
  end

  local adapter = self:get_adapter()
  local metadata = {}
  local db_self = self  -- Capture for callback

  -- Step 1: Load columns for all tables/views
  local function load_columns(next_step)
    if not adapter.get_all_columns_bulk_query then
      next_step()
      return
    end

    local query = adapter:get_all_columns_bulk_query(self.db_name)

    adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 60000,
      on_complete = function(results, err)
        if err then
          if opts.on_error then opts.on_error(err)
          elseif opts.on_complete then opts.on_complete(nil, err) end
          return
        end

        -- Parse into search text map (for backward compatibility)
        if adapter.parse_all_columns_bulk then
          local columns_meta = adapter:parse_all_columns_bulk(results)
          for k, v in pairs(columns_meta) do
            metadata[k] = v
          end
        end

        -- ALSO populate actual objects with ColumnClass instances
        db_self:_populate_columns_from_bulk_results(adapter, results)

        next_step()
      end,
      on_error = function(err)
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
      end,
    })
  end

  -- Step 2: Load parameters for all procedures/functions
  local function load_parameters(next_step)
    if not adapter.get_all_parameters_bulk_query then
      next_step()
      return
    end

    local query = adapter:get_all_parameters_bulk_query(self.db_name)

    adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 60000,
      on_complete = function(results, err)
        if err then
          if opts.on_error then opts.on_error(err)
          elseif opts.on_complete then opts.on_complete(nil, err) end
          return
        end

        -- Parse into search text map (for backward compatibility)
        if adapter.parse_all_parameters_bulk then
          local params_meta = adapter:parse_all_parameters_bulk(results)
          for k, v in pairs(params_meta) do
            if metadata[k] then
              metadata[k] = metadata[k] .. " " .. v
            else
              metadata[k] = v
            end
          end
        end

        -- ALSO populate actual objects with ParameterClass instances
        db_self:_populate_parameters_from_bulk_results(adapter, results)

        next_step()
      end,
      on_error = function(err)
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
      end,
    })
  end

  -- Run sequentially: columns -> parameters -> complete
  load_columns(function()
    load_parameters(function()
      -- Cache the results for future calls
      db_self._bulk_columns_loaded = true
      db_self._bulk_metadata_cache = metadata

      if opts.on_complete then opts.on_complete(metadata, nil) end
    end)
  end)

  return "bulk_metadata"
end

---Load all definitions for all objects in bulk asynchronously
---Returns a map of "schema.object" -> "definition text"
---Queries run sequentially to avoid overloading the server
---Results are cached - subsequent calls return cached data without querying
---This method does double duty:
---  1. Returns definitions map for object search (backward compatible)
---  2. ALSO populates actual objects (Table/View/Procedure/Function definitions)
---     so tree UI and search share the same cache
---@param opts { on_complete: fun(definitions: table<string,string>?, err: string?)?, on_error: fun(err: string)?, timeout_ms: number?, force_reload: boolean? }?
---@return string task_id
function DbClass:load_all_definitions_bulk_async(opts)
  opts = opts or {}

  -- Return cached data if already loaded (unless force_reload requested)
  if self._bulk_definitions_loaded and self._bulk_definitions_cache and not opts.force_reload then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(self._bulk_definitions_cache, nil)
      end)
    end
    return "cached"
  end

  local adapter = self:get_adapter()
  local definitions = {}
  local db_self = self  -- Capture for callback

  -- Step 1: Load views, procedures, functions definitions (from sys.sql_modules)
  local function load_module_definitions(next_step)
    if not adapter.get_all_definitions_bulk_query then
      next_step()
      return
    end

    local query = adapter:get_all_definitions_bulk_query(self.db_name, nil)

    adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 60000,
      on_complete = function(results, err)
        if err then
          if opts.on_error then opts.on_error(err)
          elseif opts.on_complete then opts.on_complete(nil, err) end
          return
        end

        -- Parse into definitions map (for backward compatibility)
        if adapter.parse_definitions_bulk then
          local module_defs = adapter:parse_definitions_bulk(results)
          for k, v in pairs(module_defs) do
            definitions[k] = v
          end
        end

        -- ALSO populate actual objects with definitions
        db_self:_populate_module_definitions_from_bulk_results(results)

        next_step()
      end,
      on_error = function(err)
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
      end,
    })
  end

  -- Step 2: Load table definitions (generated CREATE TABLE scripts)
  local function load_table_definitions(next_step)
    if not adapter.get_all_table_definitions_bulk_query then
      next_step()
      return
    end

    local query = adapter:get_all_table_definitions_bulk_query(self.db_name, nil)

    adapter:execute_rpc_async(self:_get_db_connection_config(), query, {
      timeout_ms = opts.timeout_ms or 60000,
      on_complete = function(results, err)
        if err then
          if opts.on_error then opts.on_error(err)
          elseif opts.on_complete then opts.on_complete(nil, err) end
          return
        end

        -- Parse into definitions map (for backward compatibility)
        if adapter.parse_table_definitions_bulk then
          local table_defs = adapter:parse_table_definitions_bulk(results)
          for k, v in pairs(table_defs) do
            definitions[k] = v
          end
        end

        -- ALSO populate actual table objects with definitions
        db_self:_populate_table_definitions_from_bulk_results(results)

        next_step()
      end,
      on_error = function(err)
        if opts.on_error then opts.on_error(err)
        elseif opts.on_complete then opts.on_complete(nil, err) end
      end,
    })
  end

  -- Run sequentially: module defs -> table defs -> complete
  load_module_definitions(function()
    load_table_definitions(function()
      -- Cache the results for future calls
      db_self._bulk_definitions_loaded = true
      db_self._bulk_definitions_cache = definitions

      if opts.on_complete then opts.on_complete(definitions, nil) end
    end)
  end)

  return "bulk_definitions"
end

return DbClass
