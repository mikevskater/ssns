local BaseDbObject = require('ssns.classes.base')

---@class ProcedureClass : BaseDbObject
---@field procedure_name string The procedure name
---@field schema_name string The schema name
---@field parent SchemaClass The parent schema object
---@field parameters ParameterClass[]? Array of parameter objects
---@field parameters_loaded boolean Whether parameters have been loaded
---@field definition string? The procedure definition SQL
---@field definition_loaded boolean Whether definition has been loaded
local ProcedureClass = setmetatable({}, { __index = BaseDbObject })
ProcedureClass.__index = ProcedureClass

---Create a new Procedure instance
---@param opts {name: string, schema_name: string, parent: SchemaClass}
---@return ProcedureClass
function ProcedureClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), ProcedureClass)

  self.object_type = "procedure"
  self.procedure_name = opts.name
  self.schema_name = opts.schema_name
  self.parameters = nil
  self.parameters_loaded = false
  self.definition = nil
  self.definition_loaded = false

  -- Set appropriate icon for procedure
  self.ui_state.icon = ""  -- Procedure icon

  return self
end

---Get display name with schema prefix (e.g., [dbo].[ProcedureName])
---@return string display_name
function ProcedureClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.procedure_name)
  end
  return self.procedure_name
end

---Load procedure children (parameters and actions) - lazy loading
---@return boolean success
function ProcedureClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes for UI
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI (EXEC, View Definition, etc.)
function ProcedureClass:create_action_nodes()
  self:clear_children()

  -- Add EXEC action
  local exec_action = BaseDbObject.new({
    name = "EXEC",
    parent = self,
  })
  exec_action.ui_state.icon = ""
  exec_action.object_type = "action"
  exec_action.action_type = "exec"
  exec_action.is_loaded = true

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

  -- Add Procedure Definition action (ALTER shows definition)
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

---Load parameters for this procedure (lazy loading)
---@return ParameterClass[]
function ProcedureClass:load_parameters()
  if self.parameters_loaded then
    return self.parameters
  end

  local adapter = self:get_adapter()

  -- Navigate up: Procedure -> Database (no schemas in new structure)
  local db = self.parent

  -- Get parameters query from adapter
  local query = adapter:get_parameters_query(db.db_name, self.schema_name, self.procedure_name, "PROCEDURE")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local parameters = adapter:parse_parameters(results)

  -- Create parameter objects (don't set parent to avoid adding to procedure's children)
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
function ProcedureClass:get_parameters()
  if not self.parameters_loaded then
    self:load_parameters()
  end
  return self.parameters
end

---Load the procedure definition SQL
---@return string? definition
function ProcedureClass:load_definition()
  if self.definition_loaded then
    return self.definition
  end

  local adapter = self:get_adapter()

  -- Navigate up: Procedure -> Database (no schemas in new structure)
  local db = self.parent

  -- Get definition query from adapter
  local query = adapter:get_definition_query(db.db_name, self.schema_name, self.procedure_name, "PROCEDURE")

  -- Execute query (no delimiter for multi-line text)
  local results = adapter:execute(self:get_server().connection, query, { use_delimiter = false })

  -- Extract definition from results
  if results and #results > 0 then
    self.definition = results[1].definition or results[1][1]
  end

  self.definition_loaded = true
  return self.definition
end

---Get the procedure definition (load if not already loaded)
---@return string?
function ProcedureClass:get_definition()
  if not self.definition_loaded then
    self:load_definition()
  end
  return self.definition
end

---Generate an EXEC statement for this procedure
---@return string sql
function ProcedureClass:generate_exec()
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.procedure_name
  )

  local parameters = self:get_parameters()

  if #parameters == 0 then
    -- No parameters
    return string.format("EXEC %s;", qualified_name)
  end

  -- Build parameter list with placeholders
  local param_parts = {}
  for _, param in ipairs(parameters) do
    if param.mode ~= "OUT" then
      table.insert(param_parts, string.format("%s = ?", param.name))
    end
  end

  return string.format("EXEC %s %s;", qualified_name, table.concat(param_parts, ", "))
end

---Generate a DROP statement for this procedure
---@return string sql
function ProcedureClass:generate_drop()
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.procedure_name
  )

  return string.format("DROP PROCEDURE %s;", qualified_name)
end

---Get the full qualified name for this procedure
---@return string
function ProcedureClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.procedure_name
  )
end

---Get string representation for debugging
---@return string
function ProcedureClass:to_string()
  return string.format(
    "ProcedureClass{name=%s, schema=%s, parameters=%d}",
    self.name,
    self.schema_name,
    self.parameters and #self.parameters or 0
  )
end

return ProcedureClass
