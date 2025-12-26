---@class UiParamInput
---Parameter input UI for stored procedures
local UiParamInput = {}

local UiFloatForm = require('nvim-float.float.form')

---@class ProcedureParameter
---@field name string Parameter name (e.g., "@param1")
---@field data_type string Data type (e.g., "int", "varchar(50)")
---@field direction string Direction: "IN", "OUT", "INOUT"
---@field default_value string? Default value if available
---@field is_nullable boolean Whether parameter accepts NULL
---@field value string User-entered value

---@type table? Current UiFloatForm state
local state = nil

---Show parameter input form
---@param procedure_name string The procedure name
---@param server_name string The server name
---@param database_name string? The database name
---@param parameters ProcedureParameter[] List of parameters
---@param callback function Callback function(values: table<string, string>)
function UiParamInput.show_input(procedure_name, server_name, database_name, parameters, callback)
  if #parameters == 0 then
    vim.notify("SSNS: Procedure has no input parameters", vim.log.levels.INFO)
    callback({})
    return
  end

  -- Filter out output-only parameters
  local input_params = {}
  for _, param in ipairs(parameters) do
    if param.direction == "IN" or param.direction == "INOUT" then
      param.value = param.default_value or ""
      table.insert(input_params, param)
    end
  end

  if #input_params == 0 then
    vim.notify("SSNS: Procedure has no input parameters", vim.log.levels.INFO)
    callback({})
    return
  end

  -- Build header text
  local header = {
    string.format("Server: %s | Database: %s", server_name, database_name or "N/A"),
    string.rep("─", 50),
  }

  -- Build form fields
  local fields = {}
  for i, param in ipairs(input_params) do
    local has_default = param.has_default or param.default_value
    local optional_info = has_default and " [OPTIONAL]" or ""
    local default_info = param.default_value and string.format(", default: %s", param.default_value) 
      or (has_default and ", has default" or "")

    table.insert(fields, {
      type = "text",
      name = param.name,  -- Use parameter name as field name
      label = string.format("%s (%s, %s%s)%s",
        param.name, param.data_type, param.direction, default_info, optional_info),
      value = param.value or "",
      validate = function(value)
        -- All fields are optional if they have defaults
        if value == "" and not has_default and param.direction ~= "INOUT" then
          return false, "Required parameter"
        end
        return true
      end,
    })
  end

  -- Create the form
  state = UiFloatForm.create({
    title = string.format(" Procedure Parameters: %s ", procedure_name),
    header = header,
    fields = fields,
    width = 60,
    height = nil,  -- Auto-calculate based on fields
    on_submit = function(values)
      -- Transform values back to parameter table format expected by callback
      callback(values)
      state = nil
    end,
    on_cancel = function()
      state = nil
    end,
  })

  -- Render the form
  if state then
    UiFloatForm.render(state)
  end
end

---Check if parameter input is open
---@return boolean
function UiParamInput.is_open()
  return state ~= nil
end

return UiParamInput
