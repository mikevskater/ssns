local BaseDbObject = require('ssns.classes.base')

---@class ConstraintClass : BaseDbObject
---@field constraint_name string The constraint name
---@field constraint_type string Constraint type (e.g., "PRIMARY_KEY_CONSTRAINT", "FOREIGN_KEY_CONSTRAINT", "CHECK_CONSTRAINT")
---@field columns string[] Array of column names in the constraint
---@field referenced_table string? Referenced table name (for foreign keys)
---@field referenced_schema string? Referenced schema name (for foreign keys)
---@field referenced_columns string[]? Referenced column names (for foreign keys)
---@field check_clause string? Check clause expression (for check constraints)
---@field parent TableClass The parent table object
local ConstraintClass = setmetatable({}, { __index = BaseDbObject })
ConstraintClass.__index = ConstraintClass

---Create a new Constraint instance
---@param opts {name: string, constraint_type: string, columns: string[], referenced_table: string?, referenced_schema: string?, referenced_columns: string[]?, check_clause: string?, parent: TableClass}
---@return ConstraintClass
function ConstraintClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), ConstraintClass)

  self.constraint_name = opts.name
  self.constraint_type = opts.constraint_type
  self.columns = opts.columns or {}
  self.referenced_table = opts.referenced_table
  self.referenced_schema = opts.referenced_schema
  self.referenced_columns = opts.referenced_columns
  self.check_clause = opts.check_clause

  -- Constraints don't have children
  self.is_loaded = true

  -- Set object type for highlighting
  self.object_type = "key"

  -- Set appropriate icon based on constraint type
  if self:is_primary_key() then
    self.ui_state.icon = ""  -- Key icon
  elseif self:is_foreign_key() then
    self.ui_state.icon = ""  -- Link icon
  elseif self:is_unique() then
    self.ui_state.icon = ""  -- Unique icon
  elseif self:is_check() then
    self.ui_state.icon = ""  -- Check icon
  else
    self.ui_state.icon = ""  -- Default constraint icon
  end

  return self
end

---Check if this is a primary key constraint
---@return boolean
function ConstraintClass:is_primary_key()
  return self.constraint_type == "PRIMARY_KEY_CONSTRAINT"
    or self.constraint_type == "PRIMARY KEY"
    or self.constraint_type:match("PK") ~= nil
end

---Check if this is a foreign key constraint
---@return boolean
function ConstraintClass:is_foreign_key()
  return self.constraint_type == "FOREIGN_KEY_CONSTRAINT"
    or self.constraint_type == "FOREIGN KEY"
    or self.constraint_type:match("F") ~= nil
end

---Check if this is a unique constraint
---@return boolean
function ConstraintClass:is_unique()
  return self.constraint_type == "UNIQUE_CONSTRAINT"
    or self.constraint_type == "UNIQUE"
    or self.constraint_type:match("UQ") ~= nil
end

---Check if this is a check constraint
---@return boolean
function ConstraintClass:is_check()
  return self.constraint_type == "CHECK_CONSTRAINT"
    or self.constraint_type == "CHECK"
    or self.constraint_type:match("C") ~= nil
end

---Check if this is a default constraint
---@return boolean
function ConstraintClass:is_default()
  return self.constraint_type == "DEFAULT_CONSTRAINT"
    or self.constraint_type == "DEFAULT"
    or self.constraint_type:match("D") ~= nil
end

---Get the constraint type string (normalized)
---@return string
function ConstraintClass:get_type_string()
  if self:is_primary_key() then
    return "PRIMARY KEY"
  elseif self:is_foreign_key() then
    return "FOREIGN KEY"
  elseif self:is_unique() then
    return "UNIQUE"
  elseif self:is_check() then
    return "CHECK"
  elseif self:is_default() then
    return "DEFAULT"
  end
  return self.constraint_type
end

---Get the columns string (comma-separated)
---@return string
function ConstraintClass:get_columns_string()
  return table.concat(self.columns, ", ")
end

---Get the foreign key reference string
---@return string?
function ConstraintClass:get_reference_string()
  if not self:is_foreign_key() or not self.referenced_table then
    return nil
  end

  local adapter = self:get_adapter()
  local ref_table = self.referenced_table

  -- Add schema if present
  if self.referenced_schema then
    ref_table = adapter:quote_identifier(self.referenced_schema) .. "." .. adapter:quote_identifier(self.referenced_table)
  else
    ref_table = adapter:quote_identifier(self.referenced_table)
  end

  -- Add columns if present
  if self.referenced_columns and #self.referenced_columns > 0 then
    ref_table = ref_table .. "(" .. table.concat(self.referenced_columns, ", ") .. ")"
  end

  return ref_table
end

---Get display name with type and details
---@return string
function ConstraintClass:get_display_name()
  local parts = { self.constraint_name }

  -- Add type
  table.insert(parts, "|")
  table.insert(parts, self:get_type_string())

  -- Add columns
  if #self.columns > 0 then
    table.insert(parts, "|")
    table.insert(parts, "(" .. self:get_columns_string() .. ")")
  end

  -- Add foreign key reference
  if self:is_foreign_key() then
    local ref = self:get_reference_string()
    if ref then
      table.insert(parts, "|")
      table.insert(parts, "→ " .. ref)
    end
  end

  -- Add check clause (truncated)
  if self:is_check() and self.check_clause then
    local clause = self.check_clause
    if #clause > 50 then
      clause = clause:sub(1, 47) .. "..."
    end
    table.insert(parts, "|")
    table.insert(parts, clause)
  end

  return table.concat(parts, " ")
end

---Generate an ALTER TABLE DROP CONSTRAINT statement
---@return string sql
function ConstraintClass:generate_drop()
  local adapter = self:get_adapter()

  -- Get parent table
  local parent = self.parent
  while parent and parent.object_type == "key_group" do
    parent = parent.parent
  end

  if not parent then
    return ""
  end

  local qualified_table_name = adapter:get_qualified_name(
    parent.parent.parent.db_name,
    parent.schema_name,
    parent.table_name
  )

  return string.format(
    "ALTER TABLE %s DROP CONSTRAINT %s;",
    qualified_table_name,
    adapter:quote_identifier(self.constraint_name)
  )
end

---Get string representation for debugging
---@return string
function ConstraintClass:to_string()
  return string.format(
    "ConstraintClass{name=%s, type=%s, columns=%d, fk=%s}",
    self.name,
    self:get_type_string(),
    #self.columns,
    self:is_foreign_key() and (self.referenced_table or "unknown") or "N/A"
  )
end

return ConstraintClass
