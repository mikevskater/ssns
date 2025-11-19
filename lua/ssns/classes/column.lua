local BaseDbObject = require('ssns.classes.base')

---@class ColumnClass : BaseDbObject
---@field column_name string The column name
---@field data_type string The data type (e.g., "int", "nvarchar", "datetime")
---@field max_length number? Maximum length for character/binary types
---@field precision number? Numeric precision
---@field scale number? Numeric scale
---@field nullable boolean Whether the column accepts NULL
---@field is_identity boolean Whether this is an identity/auto-increment column
---@field default string? Default value expression
---@field ordinal_position number? Column position in table
---@field parent TableClass|ViewClass The parent table or view object
local ColumnClass = setmetatable({}, { __index = BaseDbObject })
ColumnClass.__index = ColumnClass

---Create a new Column instance
---@param opts {name: string, data_type: string, nullable: boolean, is_identity: boolean?, default: string?, max_length: number?, precision: number?, scale: number?, parent: BaseDbObject}
---@return ColumnClass
function ColumnClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), ColumnClass)

  self.column_name = opts.name
  self.data_type = opts.data_type
  self.max_length = opts.max_length
  self.precision = opts.precision
  self.scale = opts.scale
  self.nullable = opts.nullable
  self.is_identity = opts.is_identity or false
  self.default = opts.default
  self.ordinal_position = opts.ordinal_position

  -- Columns don't have children
  self.is_loaded = true

  -- Set object type for highlighting
  self.object_type = "column"

  -- Set appropriate icon for column
  self.ui_state.icon = ""  -- Column icon

  return self
end

---Get the full type string (e.g., "nvarchar(50)", "decimal(18,2)")
---@return string
function ColumnClass:get_full_type()
  local type_str = self.data_type

  -- Helper to check if value is a valid number (not nil or vim.NIL)
  local function is_valid_number(val)
    return val and type(val) == "number"
  end

  -- Add length/precision/scale based on type
  if is_valid_number(self.max_length) and self.max_length > 0 then
    -- Character and binary types
    if self.max_length == -1 then
      -- MAX length in SQL Server
      type_str = type_str .. "(MAX)"
    elseif self.data_type:match("^n") then
      -- Unicode types (nvarchar, nchar) - divide by 2 for display
      type_str = string.format("%s(%d)", type_str, self.max_length / 2)
    else
      type_str = string.format("%s(%d)", type_str, self.max_length)
    end
  elseif is_valid_number(self.precision) and self.precision > 0 then
    -- Numeric types with precision
    if is_valid_number(self.scale) and self.scale > 0 then
      type_str = string.format("%s(%d,%d)", type_str, self.precision, self.scale)
    else
      type_str = string.format("%s(%d)", type_str, self.precision)
    end
  end

  return type_str
end

---Get the NULL/NOT NULL indicator
---@return string
function ColumnClass:get_nullable_string()
  return self.nullable and "NULL" or "NOT NULL"
end

---Check if this column is a primary key
---@return boolean
function ColumnClass:is_primary_key()
  -- Check if parent table has this column in a primary key constraint
  local parent = self.parent

  -- Navigate up to table if we're in a column group
  while parent and parent.object_type == "column_group" do
    parent = parent.parent
  end

  if not parent or not parent.get_constraints then
    return false
  end

  local constraints = parent:get_constraints()
  for _, constraint in ipairs(constraints) do
    if constraint.constraint_type == "PRIMARY_KEY_CONSTRAINT" or constraint.constraint_type == "PRIMARY KEY" then
      for _, col_name in ipairs(constraint.columns) do
        if col_name == self.column_name then
          return true
        end
      end
    end
  end

  return false
end

---Check if this column is a foreign key
---@return boolean
function ColumnClass:is_foreign_key()
  -- Check if parent table has this column in a foreign key constraint
  local parent = self.parent

  -- Navigate up to table if we're in a column group
  while parent and parent.object_type == "column_group" do
    parent = parent.parent
  end

  if not parent or not parent.get_constraints then
    return false
  end

  local constraints = parent:get_constraints()
  for _, constraint in ipairs(constraints) do
    if constraint.constraint_type == "FOREIGN_KEY_CONSTRAINT" or constraint.constraint_type == "FOREIGN KEY" then
      for _, col_name in ipairs(constraint.columns) do
        if col_name == self.column_name then
          return true
        end
      end
    end
  end

  return false
end

---Get the foreign key target (referenced table and column)
---@return string? referenced_table
---@return string? referenced_column
function ColumnClass:get_foreign_key_target()
  local parent = self.parent

  -- Navigate up to table if we're in a column group
  while parent and parent.object_type == "column_group" do
    parent = parent.parent
  end

  if not parent or not parent.get_constraints then
    return nil, nil
  end

  local constraints = parent:get_constraints()
  for _, constraint in ipairs(constraints) do
    if constraint.constraint_type == "FOREIGN_KEY_CONSTRAINT" or constraint.constraint_type == "FOREIGN KEY" then
      for i, col_name in ipairs(constraint.columns) do
        if col_name == self.column_name then
          local ref_table = constraint.referenced_table
          local ref_col = constraint.referenced_columns and constraint.referenced_columns[i]
          return ref_table, ref_col
        end
      end
    end
  end

  return nil, nil
end

---Get display name with type and constraints
---@return string
function ColumnClass:get_display_name()
  local parts = { self.column_name }

  -- Add type
  table.insert(parts, "|")
  table.insert(parts, self:get_full_type())

  -- Add NULL/NOT NULL
  table.insert(parts, "|")
  table.insert(parts, self:get_nullable_string())

  -- Add constraints
  local constraints = {}
  if self:is_primary_key() then
    table.insert(constraints, "PK")
  end
  if self:is_foreign_key() then
    table.insert(constraints, "FK")
  end
  if self.is_identity then
    table.insert(constraints, "IDENTITY")
  end

  if #constraints > 0 then
    table.insert(parts, "|")
    table.insert(parts, table.concat(constraints, ", "))
  end

  return table.concat(parts, " ")
end

---Get string representation for debugging
---@return string
function ColumnClass:to_string()
  return string.format(
    "ColumnClass{name=%s, type=%s, nullable=%s, pk=%s}",
    self.name,
    self:get_full_type(),
    tostring(self.nullable),
    tostring(self:is_primary_key())
  )
end

return ColumnClass
