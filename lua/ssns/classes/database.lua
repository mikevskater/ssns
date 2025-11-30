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

---Load objects from database (server-type aware)
---For schema-based servers (SQL Server, PostgreSQL): loads schemas, objects live in schemas
---For non-schema servers (MySQL): loads objects directly on database
---@return boolean success
function DbClass:load()
  if self.is_loaded then
    return true
  end

  local adapter = self:get_adapter()

  -- Check if this is a schema-based server
  if adapter.features.schemas then
    -- SQL Server/PostgreSQL: Load schemas, objects live inside schemas
    self.schemas = self:_load_schemas()

    -- Load each schema's objects
    for _, schema in ipairs(self.schemas) do
      schema:load()
    end
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

---Load schemas for this database
---@return SchemaClass[]
function DbClass:_load_schemas()
  local adapter = self:get_adapter()
  local SchemaClass = require('ssns.classes.schema')

  -- Get schemas query
  local query = adapter:get_schemas_query(self.db_name)
  local results = adapter:execute(self:get_server().connection, query)
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
  local results = adapter:execute(self:get_server().connection, query)
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
  local results = adapter:execute(self:get_server().connection, query)
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
  local results = adapter:execute(self:get_server().connection, query)
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
  local results = adapter:execute(self:get_server().connection, query)
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
  if not self.is_loaded then
    self:load()
  end
  return self.schemas or {}
end

---Get all tables (server-type aware - aggregates from schemas if needed)
---@param schema_filter string? Optional schema name to filter by
---@return TableClass[]
function DbClass:get_tables(schema_filter)
  if not self.is_loaded then
    self:load()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    local all_tables = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, t in ipairs(schema:get_tables()) do
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
---@param schema_filter string? Optional schema name to filter by
---@return ViewClass[]
function DbClass:get_views(schema_filter)
  if not self.is_loaded then
    self:load()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    local all_views = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, v in ipairs(schema:get_views()) do
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
---@param schema_filter string? Optional schema name to filter by
---@return ProcedureClass[]
function DbClass:get_procedures(schema_filter)
  if not self.is_loaded then
    self:load()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    local all_procedures = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, p in ipairs(schema:get_procedures()) do
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
---@param schema_filter string? Optional schema name to filter by
---@return FunctionClass[]
function DbClass:get_functions(schema_filter)
  if not self.is_loaded then
    self:load()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    local all_functions = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, f in ipairs(schema:get_functions()) do
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
---@param schema_filter string? Optional schema name to filter by
---@return SynonymClass[]
function DbClass:get_synonyms(schema_filter)
  if not self.is_loaded then
    self:load()
  end

  -- Schema-based servers: aggregate from schemas
  if self.schemas then
    local all_synonyms = {}
    for _, schema in ipairs(self.schemas) do
      if not schema_filter or schema.name:lower() == schema_filter:lower() then
        for _, s in ipairs(schema:get_synonyms()) do
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
