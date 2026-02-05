local BaseDbObject = require('nvim-ssns.classes.base')

---@class IndexClass : BaseDbObject
---@field index_name string The index name
---@field index_type string? Index type (e.g., "CLUSTERED", "NONCLUSTERED", "BTREE")
---@field is_unique boolean Whether this is a unique index
---@field is_primary boolean Whether this is a primary key index
---@field columns string[] Array of column names in the index
---@field parent TableClass The parent table object
local IndexClass = setmetatable({}, { __index = BaseDbObject })
IndexClass.__index = IndexClass

---Create a new Index instance
---@param opts {name: string, index_type: string?, is_unique: boolean, is_primary: boolean, columns: string[], parent: TableClass}
---@return IndexClass
function IndexClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), IndexClass)

  self.index_name = opts.name
  self.index_type = opts.index_type
  self.is_unique = opts.is_unique or false
  self.is_primary = opts.is_primary or false
  self.columns = opts.columns or {}

  -- Indexes don't have children
  self.is_loaded = true

  -- Set object type for highlighting
  self.object_type = "index"

  return self
end

---Get the index type string
---@return string
function IndexClass:get_type_string()
  if self.index_type then
    return self.index_type
  end
  return "INDEX"
end

---Get constraint indicators (UNIQUE, PK)
---@return string[]
function IndexClass:get_constraint_indicators()
  local indicators = {}

  if self.is_primary then
    table.insert(indicators, "PK")
  end

  if self.is_unique then
    table.insert(indicators, "UNIQUE")
  end

  return indicators
end

---Get the columns string (comma-separated)
---@return string
function IndexClass:get_columns_string()
  return table.concat(self.columns, ", ")
end

---Check if this index covers a set of columns
---Useful for query optimization checks
---@param column_names string[]
---@return boolean
function IndexClass:covers_columns(column_names)
  -- Check if all provided columns are in the index (in order)
  for i, col_name in ipairs(column_names) do
    if not self.columns[i] or self.columns[i] ~= col_name then
      return false
    end
  end
  return true
end

---Check if this index includes a specific column
---@param column_name string
---@return boolean
function IndexClass:includes_column(column_name)
  for _, col in ipairs(self.columns) do
    if col == column_name then
      return true
    end
  end
  return false
end

---Get display name with type and columns
---@return string
function IndexClass:get_display_name()
  local parts = { self.index_name }

  -- Add type
  table.insert(parts, "|")
  table.insert(parts, self:get_type_string())

  -- Add constraint indicators
  local indicators = self:get_constraint_indicators()
  if #indicators > 0 then
    table.insert(parts, "|")
    table.insert(parts, table.concat(indicators, ", "))
  end

  -- Add columns
  table.insert(parts, "|")
  table.insert(parts, "(" .. self:get_columns_string() .. ")")

  return table.concat(parts, " ")
end

---Get string representation for debugging
---@return string
function IndexClass:to_string()
  return string.format(
    "IndexClass{name=%s, type=%s, unique=%s, pk=%s, columns=%d}",
    self.name,
    self:get_type_string(),
    tostring(self.is_unique),
    tostring(self.is_primary),
    #self.columns
  )
end

return IndexClass
