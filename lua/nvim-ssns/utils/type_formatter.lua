---SQL type formatting utilities for SSNS
---Provides consistent type string formatting for columns and parameters
---@module ssns.utils.type_formatter

local M = {}

---Check if a value is a valid number (handles nil and vim.NIL)
---@param val any Value to check
---@return boolean is_valid True if val is a valid number
function M.is_valid_number(val)
  return val and type(val) == "number"
end

---Format a SQL data type with length/precision/scale
---Handles varchar(n), nvarchar(n), decimal(p,s), etc.
---@param opts {data_type: string, max_length: number?, precision: number?, scale: number?}
---@return string type_str Formatted type string (e.g., "nvarchar(50)", "decimal(18,2)")
function M.format_full_type(opts)
  local type_str = opts.data_type

  if not type_str then
    return "unknown"
  end

  -- Add length/precision/scale based on type
  if M.is_valid_number(opts.max_length) and opts.max_length > 0 then
    -- Character and binary types
    if opts.max_length == -1 then
      -- MAX length in SQL Server
      type_str = type_str .. "(MAX)"
    elseif type_str:match("^n") then
      -- Unicode types (nvarchar, nchar) - divide by 2 for display
      type_str = string.format("%s(%d)", type_str, opts.max_length / 2)
    else
      type_str = string.format("%s(%d)", type_str, opts.max_length)
    end
  elseif M.is_valid_number(opts.precision) and opts.precision > 0 then
    -- Numeric types with precision
    if M.is_valid_number(opts.scale) and opts.scale > 0 then
      type_str = string.format("%s(%d,%d)", type_str, opts.precision, opts.scale)
    else
      type_str = string.format("%s(%d)", type_str, opts.precision)
    end
  end

  return type_str
end

---Format type from a Column or Parameter object
---Convenience method that extracts fields from object
---@param obj {data_type: string, max_length: number?, precision: number?, scale: number?}
---@return string type_str Formatted type string
function M.format_from_object(obj)
  return M.format_full_type({
    data_type = obj.data_type,
    max_length = obj.max_length,
    precision = obj.precision,
    scale = obj.scale,
  })
end

---Get nullable string from boolean
---@param nullable boolean Whether the field is nullable
---@return string "NULL" or "NOT NULL"
function M.format_nullable(nullable)
  return nullable and "NULL" or "NOT NULL"
end

---Format a complete column definition (for CREATE TABLE, etc.)
---@param opts {name: string, data_type: string, max_length: number?, precision: number?, scale: number?, nullable: boolean?, default: string?, is_identity: boolean?}
---@return string definition Column definition string
function M.format_column_definition(opts)
  local parts = {}

  -- Column name
  table.insert(parts, opts.name)

  -- Type with length/precision
  table.insert(parts, M.format_full_type(opts))

  -- IDENTITY
  if opts.is_identity then
    table.insert(parts, "IDENTITY")
  end

  -- NULL/NOT NULL
  if opts.nullable ~= nil then
    table.insert(parts, M.format_nullable(opts.nullable))
  end

  -- DEFAULT
  if opts.default then
    table.insert(parts, "DEFAULT")
    table.insert(parts, opts.default)
  end

  return table.concat(parts, " ")
end

---Format a parameter definition (for CREATE PROCEDURE, etc.)
---@param opts {name: string, data_type: string, max_length: number?, precision: number?, scale: number?, mode: string?, has_default: boolean?}
---@return string definition Parameter definition string
function M.format_parameter_definition(opts)
  local parts = {}

  -- Parameter name (should start with @)
  local name = opts.name
  if not name:match("^@") then
    name = "@" .. name
  end
  table.insert(parts, name)

  -- Type with length/precision
  table.insert(parts, M.format_full_type(opts))

  -- OUTPUT mode
  if opts.mode == "OUT" or opts.mode == "INOUT" then
    table.insert(parts, "OUTPUT")
  end

  -- DEFAULT indicator (actual value not stored)
  if opts.has_default then
    table.insert(parts, "= <default>")
  end

  return table.concat(parts, " ")
end

return M
