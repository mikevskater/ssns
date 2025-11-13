local BaseDbObject = require('ssns.classes.base')

---@class DbClass : BaseDbObject
---@field db_name string The database name
---@field parent ServerClass The parent server object
---@field schemas SchemaClass[]? Array of schema objects
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
  self.schemas = nil
  self.is_connected = false

  -- Set appropriate icon for database
  self.ui_state.icon = ""  -- Database icon

  return self
end

---Load objects from database (vim-dadbod-ui style - no schema nodes)
---@return boolean success
function DbClass:load()
  if self.is_loaded then
    return true
  end

  local adapter = self:get_adapter()
  self:clear_children()

  -- Load all objects across ALL schemas and group by type
  -- This matches vim-dadbod-ui structure: Database -> TABLES/VIEWS/etc (no schema nodes)

  -- Load tables from all schemas
  local tables = self:load_all_tables()

  -- Load views from all schemas
  local views = self:load_all_views()

  -- Load procedures from all schemas
  local procedures = self:load_all_procedures()

  -- Load functions from all schemas
  local functions = self:load_all_functions()

  -- Create object type groups
  self:create_object_type_groups(tables, views, procedures, functions)

  self.is_loaded = true
  return true
end

---Load tables directly for databases without schema support
---@return boolean success
function DbClass:load_tables_directly()
  -- For databases like MySQL/SQLite that don't have schemas,
  -- create a single "default" schema to hold all objects
  self:clear_children()

  local SchemaClass = require('ssns.classes.schema')
  local default_schema = SchemaClass.new({
    name = self.db_name,  -- Use database name as schema name
    parent = self,
  })

  self.is_loaded = true
  return true
end

---Reload schemas from database
---@return boolean success
function DbClass:reload()
  self:clear_children()
  return self:load()
end

---Find a schema by name
---@param schema_name string
---@return SchemaClass?
function DbClass:find_schema(schema_name)
  return self:find_child(schema_name)
end

---Get all schemas
---@return SchemaClass[]
function DbClass:get_schemas()
  if not self.is_loaded then
    self:load()
  end
  return self.children
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

---Load synonyms (SQL Server specific)
---@return boolean success
function DbClass:load_synonyms()
  local adapter = self:get_adapter()

  if not adapter.features.synonyms then
    return false
  end

  -- Get synonyms query from adapter
  local query = adapter:get_synonyms_query(self.db_name, nil)

  -- Execute query
  -- TODO: Implement actual execution
  local results = adapter:execute(self:get_server().connection, query)

  -- TODO: Parse and create synonym objects
  -- This will be implemented when we create SynonymClass

  return true
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
  return string.format(
    "DbClass{name=%s, schemas=%d, connected=%s}",
    self.name,
    #self.children,
    tostring(self.is_connected)
  )
end

---Load all tables from all schemas
---@return table[] Array of table objects
function DbClass:load_all_tables()
  local adapter = self:get_adapter()

  -- Get tables query - pass nil for schema_name to get ALL tables
  local query = adapter:get_tables_query(self.db_name, nil)
  local results = adapter:execute(self:get_server().connection, query)
  local table_data_list = adapter:parse_tables(results)

  local tables = {}
  for _, table_data in ipairs(table_data_list) do
    -- Pass nil as parent to avoid auto-adding to database.children
    local table_obj = adapter:create_table(nil, table_data)
    -- Set parent manually for hierarchy navigation (without adding to children)
    table_obj.parent = self
    table.insert(tables, table_obj)
  end

  return tables
end

---Load all views from all schemas
---@return table[] Array of view objects
function DbClass:load_all_views()
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

---Load all procedures from all schemas
---@return table[] Array of procedure objects
function DbClass:load_all_procedures()
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

---Load all functions from all schemas
---@return table[] Array of function objects
function DbClass:load_all_functions()
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

---Create object type groups (TABLES, VIEWS, etc.)
---@param tables table[]
---@param views table[]
---@param procedures table[]
---@param functions table[]
function DbClass:create_object_type_groups(tables, views, procedures, functions)
  -- Create TABLES group
  if #tables > 0 then
    local tables_group = BaseDbObject.new({
      name = string.format("TABLES (%d)", #tables),
      parent = self,
    })
    tables_group.object_type = "tables_group"
    tables_group.ui_state.icon = ""

    -- Add tables to group (but keep their parent as database for hierarchy)
    for _, table_obj in ipairs(tables) do
      table.insert(tables_group.children, table_obj)
    end

    tables_group.is_loaded = true
  end

  -- Create VIEWS group
  if #views > 0 then
    local views_group = BaseDbObject.new({
      name = string.format("VIEWS (%d)", #views),
      parent = self,
    })
    views_group.object_type = "views_group"
    views_group.ui_state.icon = ""

    for _, view_obj in ipairs(views) do
      table.insert(views_group.children, view_obj)
    end

    views_group.is_loaded = true
  end

  -- Create PROCEDURES group
  if #procedures > 0 then
    local procs_group = BaseDbObject.new({
      name = string.format("PROCEDURES (%d)", #procedures),
      parent = self,
    })
    procs_group.object_type = "procedures_group"
    procs_group.ui_state.icon = ""

    for _, proc_obj in ipairs(procedures) do
      table.insert(procs_group.children, proc_obj)
    end

    procs_group.is_loaded = true
  end

  -- Create FUNCTIONS group
  if #functions > 0 then
    local funcs_group = BaseDbObject.new({
      name = string.format("FUNCTIONS (%d)", #functions),
      parent = self,
    })
    funcs_group.object_type = "functions_group"
    funcs_group.ui_state.icon = ""

    for _, func_obj in ipairs(functions) do
      table.insert(funcs_group.children, func_obj)
    end

    funcs_group.is_loaded = true
  end
end

return DbClass
