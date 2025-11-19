local BaseDbObject = require('ssns.classes.base')

---@class SchemaClass : BaseDbObject
---@field schema_name string The schema name
---@field parent DbClass The parent database object
---@field tables TableClass[]? Array of table objects
---@field views ViewClass[]? Array of view objects
---@field procedures ProcedureClass[]? Array of procedure objects
---@field functions FunctionClass[]? Array of function objects
---@field object_groups table? Grouped objects for UI display
local SchemaClass = setmetatable({}, { __index = BaseDbObject })
SchemaClass.__index = SchemaClass

---Create a new Schema instance
---@param opts {name: string, parent: DbClass}
---@return SchemaClass
function SchemaClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), SchemaClass)

  self.schema_name = opts.name
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.object_groups = nil

  -- Set appropriate icon for schema

  return self
end

---Load all objects in this schema (tables, views, procedures, functions)
---@return boolean success
function SchemaClass:load()
  if self.is_loaded then
    return true
  end

  -- Load all object types
  self:load_tables()
  self:load_views()
  self:load_procedures()
  self:load_functions()

  -- Create object groups for UI display
  self:create_object_groups()

  self.is_loaded = true
  return true
end

---Load tables in this schema
---@return boolean success
function SchemaClass:load_tables()
  local adapter = self:get_adapter()
  local db = self.parent

  -- Get tables query from adapter
  local query = adapter:get_tables_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local tables = adapter:parse_tables(results)

  -- Create table objects
  self.tables = {}
  for _, table_data in ipairs(tables) do
    local table_obj = adapter:create_table(self, table_data)
    table.insert(self.tables, table_obj)
  end

  return true
end

---Load views in this schema
---@return boolean success
function SchemaClass:load_views()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.views then
    self.views = {}
    return true
  end

  -- Get views query from adapter
  local query = adapter:get_views_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local views = adapter:parse_views(results)

  -- Create view objects
  self.views = {}
  for _, view_data in ipairs(views) do
    local view_obj = adapter:create_view(self, view_data)
    table.insert(self.views, view_obj)
  end

  return true
end

---Load stored procedures in this schema
---@return boolean success
function SchemaClass:load_procedures()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.procedures then
    self.procedures = {}
    return true
  end

  -- Get procedures query from adapter
  local query = adapter:get_procedures_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local procedures = adapter:parse_procedures(results)

  -- Create procedure objects
  self.procedures = {}
  for _, proc_data in ipairs(procedures) do
    local ProcedureClass = require('ssns.classes.procedure')
    local proc_obj = ProcedureClass.new({
      name = proc_data.name,
      schema_name = proc_data.schema,
      parent = self,
    })
    table.insert(self.procedures, proc_obj)
  end

  return true
end

---Load functions in this schema
---@return boolean success
function SchemaClass:load_functions()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.functions then
    self.functions = {}
    return true
  end

  -- Get functions query from adapter
  local query = adapter:get_functions_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local functions = adapter:parse_functions(results)

  -- Create function objects
  self.functions = {}
  for _, func_data in ipairs(functions) do
    local FunctionClass = require('ssns.classes.function')
    local func_obj = FunctionClass.new({
      name = func_data.name,
      schema_name = func_data.schema,
      function_type = func_data.type,
      parent = self,
    })
    table.insert(self.functions, func_obj)
  end

  return true
end

---Create object groups for UI display (TABLES, VIEWS, PROCEDURES, etc.)
function SchemaClass:create_object_groups()
  -- Clear existing children and rebuild with groups
  self:clear_children()

  local adapter = self:get_adapter()

  -- Create group objects that can be expanded/collapsed in UI
  -- These are special container objects

  -- TABLES group
  if self.tables and #self.tables > 0 then
    local tables_group = BaseDbObject.new({
      name = string.format("TABLES (%d)", #self.tables),
      parent = self,
    })
    tables_group.object_type = "table_group"

    -- Add actual tables as children of the group
    -- IMPORTANT: Don't change table_obj.parent - keep it as schema for hierarchy
    for _, table_obj in ipairs(self.tables) do
      -- Store reference to schema for navigation
      table_obj.schema = self
      table.insert(tables_group.children, table_obj)
    end

    tables_group.is_loaded = true
  end

  -- VIEWS group
  if self.views and #self.views > 0 then
    local views_group = BaseDbObject.new({
      name = string.format("VIEWS (%d)", #self.views),
      parent = self,
    })
    views_group.object_type = "view_group"

    -- IMPORTANT: Don't change view_obj.parent - keep it as schema for hierarchy
    for _, view_obj in ipairs(self.views) do
      view_obj.schema = self
      table.insert(views_group.children, view_obj)
    end

    views_group.is_loaded = true
  end

  -- PROCEDURES group
  if adapter.features.procedures and self.procedures and #self.procedures > 0 then
    local procs_group = BaseDbObject.new({
      name = string.format("PROCEDURES (%d)", #self.procedures),
      parent = self,
    })
    procs_group.object_type = "procedure_group"

    -- IMPORTANT: Don't change proc_obj.parent - keep it as schema for hierarchy
    for _, proc_obj in ipairs(self.procedures) do
      proc_obj.schema = self
      table.insert(procs_group.children, proc_obj)
    end

    procs_group.is_loaded = true
  end

  -- FUNCTIONS group
  if adapter.features.functions and self.functions and #self.functions > 0 then
    local funcs_group = BaseDbObject.new({
      name = string.format("FUNCTIONS (%d)", #self.functions),
      parent = self,
    })
    funcs_group.object_type = "function_group"

    -- IMPORTANT: Don't change func_obj.parent - keep it as schema for hierarchy
    for _, func_obj in ipairs(self.functions) do
      func_obj.schema = self
      table.insert(funcs_group.children, func_obj)
    end

    funcs_group.is_loaded = true
  end
end

---Reload all objects in this schema
---@return boolean success
function SchemaClass:reload()
  -- Invalidate query cache for this schema's server connection
  local Connection = require('ssns.connection')
  local server = self:get_server()
  if server and server.connection_string then
    Connection.invalidate_cache(server.connection_string)
  end

  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self:clear_children()
  self.is_loaded = false
  return self:load()
end

---Find a table by name
---@param table_name string
---@return TableClass?
function SchemaClass:find_table(table_name)
  if not self.tables then
    self:load_tables()
  end

  for _, table_obj in ipairs(self.tables) do
    if table_obj.name == table_name then
      return table_obj
    end
  end

  return nil
end

---Find a view by name
---@param view_name string
---@return ViewClass?
function SchemaClass:find_view(view_name)
  if not self.views then
    self:load_views()
  end

  for _, view_obj in ipairs(self.views) do
    if view_obj.name == view_name then
      return view_obj
    end
  end

  return nil
end

---Get all objects of a specific type
---@param object_type string "table", "view", "procedure", "function"
---@return BaseDbObject[]
function SchemaClass:get_objects_by_type(object_type)
  if object_type == "table" then
    return self.tables or {}
  elseif object_type == "view" then
    return self.views or {}
  elseif object_type == "procedure" then
    return self.procedures or {}
  elseif object_type == "function" then
    return self.functions or {}
  end

  return {}
end

---Get count of all objects in this schema
---@return number
function SchemaClass:get_object_count()
  local count = 0
  count = count + (self.tables and #self.tables or 0)
  count = count + (self.views and #self.views or 0)
  count = count + (self.procedures and #self.procedures or 0)
  count = count + (self.functions and #self.functions or 0)
  return count
end

---Get the full qualified name for this schema
---@return string
function SchemaClass:get_qualified_name()
  local adapter = self:get_adapter()
  local db = self.parent

  if adapter.features.schemas then
    return adapter:get_qualified_name(db.db_name, self.schema_name, nil)
  else
    return adapter:quote_identifier(db.db_name)
  end
end

---Get string representation for debugging
---@return string
function SchemaClass:to_string()
  return string.format(
    "SchemaClass{name=%s, tables=%d, views=%d, procs=%d, funcs=%d}",
    self.name,
    self.tables and #self.tables or 0,
    self.views and #self.views or 0,
    self.procedures and #self.procedures or 0,
    self.functions and #self.functions or 0
  )
end

return SchemaClass
