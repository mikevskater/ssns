local BaseDbObject = require('ssns.classes.base')

---@class SchemaClass : BaseDbObject
---@field schema_name string The schema name
---@field parent DbClass The parent database object
---@field tables TableClass[]? Array of table objects
---@field views ViewClass[]? Array of view objects
---@field procedures ProcedureClass[]? Array of procedure objects
---@field functions FunctionClass[]? Array of function objects
---@field synonyms SynonymClass[]? Array of synonym objects
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

  self.object_type = "schema"
  self.schema_name = opts.name
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil

  return self
end

---Load all objects in this schema (tables, views, procedures, functions, synonyms)
---@return boolean success
function SchemaClass:load()
  if self.is_loaded then
    return true
  end

  -- Load all object types into typed arrays
  -- Note: These will each make individual queries, but for schema-based servers,
  -- it's better to use the database-level bulk loading (db:get_tables(), etc.)
  -- which loads all schemas at once
  self:load_tables()
  self:load_views()
  self:load_procedures()
  self:load_functions()
  self:load_synonyms()

  self.is_loaded = true
  return true
end

---Set tables from pre-loaded bulk data
---@param table_data_list table[] Array of parsed table data from adapter
function SchemaClass:set_tables(table_data_list)
  local adapter = self:get_adapter()
  
  self.tables = {}
  for _, table_data in ipairs(table_data_list) do
    local table_obj = adapter:create_table(self, table_data)
    table.insert(self.tables, table_obj)
  end
end

---Load tables in this schema
---@return boolean success
function SchemaClass:load_tables()
  local adapter = self:get_adapter()
  local db = self.parent

  -- Get tables query from adapter
  local query = adapter:get_tables_query(db.db_name, self.schema_name)

  -- Execute query
  local results = adapter:execute(db:_get_db_connection_string(), query)

  -- Parse results
  local tables = adapter:parse_tables(results)

  -- Use set method to create objects
  self:set_tables(tables)

  return true
end

---Set views from pre-loaded bulk data
---@param view_data_list table[] Array of parsed view data from adapter
function SchemaClass:set_views(view_data_list)
  local adapter = self:get_adapter()
  
  self.views = {}
  for _, view_data in ipairs(view_data_list) do
    local view_obj = adapter:create_view(self, view_data)
    table.insert(self.views, view_obj)
  end
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
  local results = adapter:execute(db:_get_db_connection_string(), query)

  -- Parse results
  local views = adapter:parse_views(results)

  -- Use set method to create objects
  self:set_views(views)

  return true
end

---Set procedures from pre-loaded bulk data
---@param proc_data_list table[] Array of parsed procedure data from adapter
function SchemaClass:set_procedures(proc_data_list)
  local ProcedureClass = require('ssns.classes.procedure')
  
  self.procedures = {}
  for _, proc_data in ipairs(proc_data_list) do
    local proc_obj = ProcedureClass.new({
      name = proc_data.name,
      schema_name = proc_data.schema,
      parent = self,
    })
    table.insert(self.procedures, proc_obj)
  end
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
  local results = adapter:execute(db:_get_db_connection_string(), query)

  -- Parse results
  local procedures = adapter:parse_procedures(results)

  -- Use set method to create objects
  self:set_procedures(procedures)

  return true
end

---Set functions from pre-loaded bulk data
---@param func_data_list table[] Array of parsed function data from adapter
function SchemaClass:set_functions(func_data_list)
  local FunctionClass = require('ssns.classes.function')
  
  self.functions = {}
  for _, func_data in ipairs(func_data_list) do
    local func_obj = FunctionClass.new({
      name = func_data.name,
      schema_name = func_data.schema,
      function_type = func_data.type,
      parent = self,
    })
    table.insert(self.functions, func_obj)
  end
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
  local results = adapter:execute(db:_get_db_connection_string(), query)

  -- Parse results
  local functions = adapter:parse_functions(results)

  -- Use set method to create objects
  self:set_functions(functions)

  return true
end

---Set synonyms from pre-loaded bulk data
---@param syn_data_list table[] Array of parsed synonym data from adapter
function SchemaClass:set_synonyms(syn_data_list)
  local SynonymClass = require('ssns.classes.synonym')
  
  self.synonyms = {}
  for _, syn_data in ipairs(syn_data_list) do
    local syn_obj = SynonymClass.new({
      name = syn_data.name,
      schema_name = syn_data.schema,
      base_object_name = syn_data.base_object_name,
      base_object_type = syn_data.base_object_type,
      parent = self,
    })
    table.insert(self.synonyms, syn_obj)
  end
end

---Load synonyms in this schema
---@return boolean success
function SchemaClass:load_synonyms()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.synonyms then
    self.synonyms = {}
    return true
  end

  -- Get synonyms query from adapter
  local query = adapter:get_synonyms_query(db.db_name, self.schema_name)

  -- Execute query
  local results = adapter:execute(db:_get_db_connection_string(), query)

  -- Parse results
  local synonyms = adapter:parse_synonyms(results)

  -- Use set method to create objects
  self:set_synonyms(synonyms)

  return true
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

  -- Clear typed arrays
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil
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

---Find a synonym by name
---@param synonym_name string
---@return SynonymClass?
function SchemaClass:find_synonym(synonym_name)
  if not self.synonyms then
    self:load_synonyms()
  end

  for _, syn_obj in ipairs(self.synonyms) do
    if syn_obj.name == synonym_name then
      return syn_obj
    end
  end

  return nil
end

---Get all synonyms in this schema
---@param opts table? Options { skip_load: boolean? }
---@return SynonymClass[]
function SchemaClass:get_synonyms(opts)
  opts = opts or {}
  if not self.synonyms and not opts.skip_load then
    self:load_synonyms()
  end
  return self.synonyms or {}
end

---Get all tables in this schema
---@param opts table? Options { skip_load: boolean? }
---@return TableClass[]
function SchemaClass:get_tables(opts)
  opts = opts or {}
  if not self.tables and not opts.skip_load then
    self:load_tables()
  end
  return self.tables or {}
end

---Get all views in this schema
---@param opts table? Options { skip_load: boolean? }
---@return ViewClass[]
function SchemaClass:get_views(opts)
  opts = opts or {}
  if not self.views and not opts.skip_load then
    self:load_views()
  end
  return self.views or {}
end

---Get all procedures in this schema
---@param opts table? Options { skip_load: boolean? }
---@return ProcedureClass[]
function SchemaClass:get_procedures(opts)
  opts = opts or {}
  if not self.procedures and not opts.skip_load then
    self:load_procedures()
  end
  return self.procedures or {}
end

---Get all functions in this schema
---@param opts table? Options { skip_load: boolean? }
---@return FunctionClass[]
function SchemaClass:get_functions(opts)
  opts = opts or {}
  if not self.functions and not opts.skip_load then
    self:load_functions()
  end
  return self.functions or {}
end

---Get all objects of a specific type
---@param object_type string "table", "view", "procedure", "function", "synonym"
---@return BaseDbObject[]
function SchemaClass:get_objects_by_type(object_type)
  if object_type == "table" then
    return self:get_tables()
  elseif object_type == "view" then
    return self:get_views()
  elseif object_type == "procedure" then
    return self:get_procedures()
  elseif object_type == "function" then
    return self:get_functions()
  elseif object_type == "synonym" then
    return self:get_synonyms()
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
  count = count + (self.synonyms and #self.synonyms or 0)
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
    "SchemaClass{name=%s, tables=%d, views=%d, procs=%d, funcs=%d, synonyms=%d}",
    self.name,
    self.tables and #self.tables or 0,
    self.views and #self.views or 0,
    self.procedures and #self.procedures or 0,
    self.functions and #self.functions or 0,
    self.synonyms and #self.synonyms or 0
  )
end

return SchemaClass
