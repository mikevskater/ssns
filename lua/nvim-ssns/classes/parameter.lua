local BaseDbObject = require('nvim-ssns.classes.base')
local TypeFormatter = require('nvim-ssns.utils.type_formatter')

---@class ParameterClass : BaseDbObject
---@field parameter_name string The parameter name
---@field data_type string The data type
---@field mode string Parameter mode: "IN", "OUT", "INOUT"
---@field has_default boolean Whether this parameter has a default value
---@field max_length number? Maximum length for character/binary types
---@field precision number? Numeric precision
---@field scale number? Numeric scale
---@field ordinal_position number? Parameter position
---@field parent ProcedureClass|FunctionClass The parent procedure or function object
local ParameterClass = setmetatable({}, { __index = BaseDbObject })
ParameterClass.__index = ParameterClass

---Create a new Parameter instance
---@param opts {name: string, data_type: string, mode: string, has_default: boolean?, max_length: number?, precision: number?, scale: number?, parent: BaseDbObject}
---@return ParameterClass
function ParameterClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), ParameterClass)

  self.parameter_name = opts.name
  self.data_type = opts.data_type
  self.mode = opts.mode or "IN"
  self.has_default = opts.has_default or false
  self.max_length = opts.max_length
  self.precision = opts.precision
  self.scale = opts.scale
  self.ordinal_position = opts.ordinal_position

  -- Parameters don't have children
  self.is_loaded = true

  -- Set object type for highlighting
  self.object_type = "parameter"

  return self
end

---Get the full type string (e.g., "nvarchar(50)", "decimal(18,2)")
---@return string
function ParameterClass:get_full_type()
  return TypeFormatter.format_from_object(self)
end

---Get the mode indicator (IN/OUT/INOUT)
---@return string
function ParameterClass:get_mode_string()
  return self.mode
end

---Check if this is an output parameter
---@return boolean
function ParameterClass:is_output()
  return self.mode == "OUT" or self.mode == "INOUT"
end

---Check if this is an input parameter
---@return boolean
function ParameterClass:is_input()
  return self.mode == "IN" or self.mode == "INOUT"
end

---Get display name with type and mode
---@return string
function ParameterClass:get_display_name()
  local parts = { self.parameter_name }

  -- Add type
  table.insert(parts, "|")
  table.insert(parts, self:get_full_type())

  -- Add mode
  table.insert(parts, "|")
  table.insert(parts, self:get_mode_string())

  -- Add default indicator
  if self.has_default then
    table.insert(parts, "|")
    table.insert(parts, "DEFAULT")
  end

  return table.concat(parts, " ")
end

---Get string representation for debugging
---@return string
function ParameterClass:to_string()
  return string.format(
    "ParameterClass{name=%s, type=%s, mode=%s, default=%s}",
    self.name,
    self:get_full_type(),
    self.mode,
    tostring(self.has_default)
  )
end

return ParameterClass
