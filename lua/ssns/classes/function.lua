local BaseDbObject = require('ssns.classes.base')

---@class FunctionClass : BaseDbObject
---@field function_name string The function name
---@field schema_name string The schema name
---@field function_type string? Function type (e.g., "SCALAR_FUNCTION", "TABLE_VALUED_FUNCTION")
---@field parent SchemaClass The parent schema object
---@field parameters ParameterClass[]? Array of parameter objects
---@field parameters_loaded boolean Whether parameters have been loaded
---@field definition string? The function definition SQL
---@field definition_loaded boolean Whether definition has been loaded
local FunctionClass = setmetatable({}, { __index = BaseDbObject })
FunctionClass.__index = FunctionClass

---Create a new Function instance
---@param opts {name: string, schema_name: string, function_type: string?, parent: SchemaClass}
---@return FunctionClass
function FunctionClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), FunctionClass)

  self.object_type = "function"
  self.function_name = opts.name
  self.schema_name = opts.schema_name
  self.function_type = opts.function_type
  self.parameters = nil
  self.parameters_loaded = false
  self.definition = nil
  self.definition_loaded = false

  -- Set appropriate icon for function
  self.ui_state.icon = ""  -- Function icon

  return self
end

---Get display name with schema prefix (e.g., [dbo].[FunctionName])
---@return string display_name
function FunctionClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.function_name)
  end
  return self.function_name
end

---Load function children (parameters and actions) - lazy loading
---@return boolean success
function FunctionClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes for UI
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI (SELECT, View Definition, etc.)
function FunctionClass:create_action_nodes()
  self:clear_children()

  -- Add SELECT action (functions are used in SELECT)
  local select_action = BaseDbObject.new({
    name = "SELECT",
    parent = self,
  })
  select_action.ui_state.icon = ""
  select_action.object_type = "action"
  select_action.action_type = "select"
  select_action.is_loaded = true

  -- Add Parameters group (lazy loaded when expanded)
  local params_group = BaseDbObject.new({
    name = "Parameters",
    parent = self,
  })
  params_group.ui_state.icon = ""
  params_group.object_type = "parameter_group"

  -- Override load for parameters group
  params_group.load = function(group)
    if group.is_loaded then
      return true
    end
    self:load_parameters()
    group:clear_children()
    for _, param in ipairs(self.parameters) do
      -- Don't set parent - just add to children manually to avoid auto-add
      table.insert(group.children, param)
    end
    group.is_loaded = true
    return true
  end

  -- Add Function Definition action (ALTER shows definition)
  local definition_action = BaseDbObject.new({
    name = "ALTER",
    parent = self,
  })
  definition_action.ui_state.icon = ""
  definition_action.object_type = "action"
  definition_action.action_type = "alter"
  definition_action.is_loaded = true

  -- Add DROP action
  local drop_action = BaseDbObject.new({
    name = "DROP",
    parent = self,
  })
  drop_action.ui_state.icon = ""
  drop_action.object_type = "action"
  drop_action.action_type = "drop"
  drop_action.is_loaded = true

  -- Add DEPENDENCIES action
  local dependencies_action = BaseDbObject.new({
    name = "DEPENDENCIES",
    parent = self,
  })
  dependencies_action.ui_state.icon = ""
  dependencies_action.object_type = "action"
  dependencies_action.action_type = "dependencies"
  dependencies_action.is_loaded = true
end

---Load parameters for this function (lazy loading)
---@return ParameterClass[]
function FunctionClass:load_parameters()
  if self.parameters_loaded then
    return self.parameters
  end

  local adapter = self:get_adapter()

  -- Navigate up: Function -> Database (no schemas in new structure)
  local db = self.parent

  -- Get parameters query from adapter
  local query = adapter:get_parameters_query(db.db_name, self.schema_name, self.function_name, "FUNCTION")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local parameters = adapter:parse_parameters(results)

  -- Create parameter objects (don't set parent to avoid adding to function's children)
  self.parameters = {}
  for _, param_data in ipairs(parameters) do
    local ParameterClass = require('ssns.classes.parameter')
    local param_obj = ParameterClass.new({
      name = param_data.name,
      data_type = param_data.data_type,
      mode = param_data.mode,
      has_default = param_data.has_default,
      max_length = param_data.max_length,
      precision = param_data.precision,
      scale = param_data.scale,
      parent = nil,
    })
    table.insert(self.parameters, param_obj)
  end

  self.parameters_loaded = true
  return self.parameters
end

---Get parameters (load if not already loaded)
---@return ParameterClass[]
function FunctionClass:get_parameters()
  if not self.parameters_loaded then
    self:load_parameters()
  end
  return self.parameters
end

---Load the function definition SQL
---@return string? definition
function FunctionClass:load_definition()
  if self.definition_loaded then
    return self.definition
  end

  local adapter = self:get_adapter()

  -- Navigate up: Function -> Database (no schemas in new structure)
  local db = self.parent

  -- Get definition query from adapter
  local query = adapter:get_definition_query(db.db_name, self.schema_name, self.function_name, "FUNCTION")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Extract definition from results
  if results and #results > 0 then
    self.definition = results[1].definition or results[1][1]
  end

  self.definition_loaded = true
  return self.definition
end

---Get the function definition (load if not already loaded)
---@return string?
function FunctionClass:get_definition()
  if not self.definition_loaded then
    self:load_definition()
  end
  return self.definition
end

---Check if this is a table-valued function
---@return boolean
function FunctionClass:is_table_valued()
  if not self.function_type then
    return false
  end

  return self.function_type:match("TABLE") ~= nil
    or self.function_type == "IF"  -- SQL Server inline table-valued
    or self.function_type == "TF"  -- SQL Server multi-statement table-valued
end

---Generate a SELECT statement for this function
---@return string sql
function FunctionClass:generate_select()
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.function_name
  )

  local parameters = self:get_parameters()

  -- Build parameter list with placeholders
  local param_parts = {}
  for _, param in ipairs(parameters) do
    table.insert(param_parts, "?")
  end

  local param_list = #param_parts > 0 and table.concat(param_parts, ", ") or ""

  if self:is_table_valued() then
    -- Table-valued function - use FROM
    return string.format("SELECT * FROM %s(%s);", qualified_name, param_list)
  else
    -- Scalar function - use SELECT
    return string.format("SELECT %s(%s);", qualified_name, param_list)
  end
end

---Generate a DROP statement for this function
---@return string sql
function FunctionClass:generate_drop()
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.function_name
  )

  return string.format("DROP FUNCTION %s;", qualified_name)
end

---Get the full qualified name for this function
---@return string
function FunctionClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.function_name
  )
end

---Get string representation for debugging
---@return string
function FunctionClass:to_string()
  return string.format(
    "FunctionClass{name=%s, schema=%s, type=%s, parameters=%d}",
    self.name,
    self.schema_name,
    self.function_type or "unknown",
    self.parameters and #self.parameters or 0
  )
end

return FunctionClass
