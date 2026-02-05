local BaseDbObject = require('nvim-ssns.classes.base')

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

  self:add_action("EXEC", "exec")

  self:add_lazy_group("Parameters", "parameter_group", function()
    self:load_parameters()
    return self.parameters
  end)

  self:add_action("ALTER", "alter")
  self:add_action("DROP", "drop")
  self:add_action("DEPENDENCIES", "dependencies")
end

---Load parameters for this procedure (lazy loading)
---@return ParameterClass[]
function ProcedureClass:load_parameters()
  if self.parameters_loaded then
    return self.parameters
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Get parameters query from adapter
  local query = adapter:get_parameters_query(db.db_name, self.schema_name, self.procedure_name, "PROCEDURE")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Parse results
  local parameters = adapter:parse_parameters(results)

  -- Create parameter objects (don't set parent to avoid adding to procedure's children)
  self.parameters = {}
  for _, param_data in ipairs(parameters) do
    local ParameterClass = require('nvim-ssns.classes.parameter')
    local param_obj = ParameterClass.new({
      name = param_data.name,
      data_type = param_data.data_type,
      mode = param_data.direction or param_data.mode,  -- Support both 'direction' and 'mode'
      has_default = param_data.has_default,
      max_length = param_data.max_length,
      precision = param_data.precision,
      scale = param_data.scale,
      parent = nil,
    })
    -- Also copy other fields needed by param_input UI
    param_obj.direction = param_data.direction or param_data.mode
    param_obj.default_value = param_data.default_value
    param_obj.is_nullable = param_data.is_nullable
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

  -- Navigate to database based on server type:
  -- Schema-based (SQL Server, PostgreSQL): Procedure -> Schema -> Database
  -- Non-schema (MySQL, SQLite): Procedure -> Database
  local db
  if adapter.features.schemas then
    db = self.parent.parent  -- Procedure -> Schema -> Database
  else
    db = self.parent  -- Procedure -> Database
  end

  -- Get definition query from adapter
  local query = adapter:get_definition_query(db.db_name, self.schema_name, self.procedure_name, "PROCEDURE")

  -- Execute query
  local results = adapter:execute(self:get_server().connection_config, query, { use_delimiter = false })

  -- Use adapter's parse method for consistent result handling
  self.definition = adapter:parse_definition(results)

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
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
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
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
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

---Get metadata info for display in floating window
---@return table metadata Standardized metadata structure with sections
function ProcedureClass:get_metadata_info()
  local parameters = self:get_parameters()
  local rows = {}

  for _, param in ipairs(parameters or {}) do
    local name = param.parameter_name or param.name or ""
    local full_type = param.get_full_type and param:get_full_type() or param.data_type or ""
    local mode = param.mode or param.direction or "IN"
    local has_default = param.has_default
    local default_val = "-"
    if param.default_value and param.default_value ~= "" then
      default_val = param.default_value
    elseif has_default then
      default_val = "(has default)"
    end

    table.insert(rows, {name, full_type, mode, default_val})
  end

  return {
    sections = {
      {
        title = "PARAMETERS",
        headers = {"Name", "Type", "Mode", "Default"},
        rows = rows,
      },
    },
  }
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class ProcedureLoadAsyncOpts : ExecutorOpts
---@field on_complete fun(result: any, error: string?)? Completion callback

---Load parameters for this procedure asynchronously
---@param opts ProcedureLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function ProcedureClass:load_parameters_async(opts)
  opts = opts or {}
  local Executor = require('nvim-ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading parameters...")
    local parameters = self:load_parameters()
    ctx.report_progress(100, "Parameters loaded")
    return parameters
  end, {
    name = opts.name or string.format("Loading parameters for %s", self.procedure_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load procedure definition asynchronously
---@param opts ProcedureLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function ProcedureClass:load_definition_async(opts)
  opts = opts or {}
  local Executor = require('nvim-ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading definition...")
    local definition = self:load_definition()
    ctx.report_progress(100, "Definition loaded")
    return definition
  end, {
    name = opts.name or string.format("Loading definition for %s", self.procedure_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

return ProcedureClass
