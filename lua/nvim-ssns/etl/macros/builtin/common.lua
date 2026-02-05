---Built-in common helper macros for ETL scripts
---@module ssns.etl.macros.builtin.common

return {
  ---Return first non-nil value (like SQL COALESCE)
  ---@param ... any Values to check
  ---@return any value First non-nil value
  coalesce = function(...)
    local args = { ... }
    for i = 1, select("#", ...) do
      if args[i] ~= nil then
        return args[i]
      end
    end
    return nil
  end,

  ---Safe division that returns default on divide by zero
  ---@param numerator number
  ---@param denominator number
  ---@param default number? Default value if denominator is 0 (default: 0)
  ---@return number result
  safe_divide = function(numerator, denominator, default)
    default = default or 0
    if denominator == 0 or denominator == nil then
      return default
    end
    return numerator / denominator
  end,

  ---Round a number to specified decimal places
  ---@param value number Value to round
  ---@param decimals number? Decimal places (default: 0)
  ---@return number rounded
  round = function(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
  end,

  ---Truncate a number to specified decimal places (no rounding)
  ---@param value number Value to truncate
  ---@param decimals number? Decimal places (default: 0)
  ---@return number truncated
  truncate = function(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult) / mult
  end,

  ---Clamp a value between min and max
  ---@param value number Value to clamp
  ---@param min number Minimum value
  ---@param max number Maximum value
  ---@return number clamped
  clamp = function(value, min, max)
    if value < min then
      return min
    elseif value > max then
      return max
    end
    return value
  end,

  ---Check if value is nil or empty string
  ---@param value any Value to check
  ---@return boolean is_empty
  is_empty = function(value)
    return value == nil or value == ""
  end,

  ---Check if value is not nil and not empty string
  ---@param value any Value to check
  ---@return boolean has_value
  has_value = function(value)
    return value ~= nil and value ~= ""
  end,

  ---Default value if nil or empty
  ---@param value any Value to check
  ---@param default any Default to return if nil or empty
  ---@return any result
  default_if_empty = function(value, default)
    if value == nil or value == "" then
      return default
    end
    return value
  end,

  ---Convert value to number, returning default if conversion fails
  ---@param value any Value to convert
  ---@param default number? Default value (default: 0)
  ---@return number result
  to_number = function(value, default)
    default = default or 0
    local num = tonumber(value)
    return num or default
  end,

  ---Convert value to string safely
  ---@param value any Value to convert
  ---@param nil_value string? Value to use for nil (default: "")
  ---@return string result
  to_string = function(value, nil_value)
    nil_value = nil_value or ""
    if value == nil then
      return nil_value
    end
    return tostring(value)
  end,

  ---Check if value is in a list
  ---@param value any Value to check
  ---@param list table List to search
  ---@return boolean found
  in_list = function(value, list)
    for _, v in ipairs(list) do
      if v == value then
        return true
      end
    end
    return false
  end,

  ---Get value from nested table path safely
  ---@param tbl table Table to traverse
  ---@param path string Dot-separated path (e.g., "a.b.c")
  ---@param default any? Default if path not found
  ---@return any value
  get_path = function(tbl, path, default)
    local current = tbl
    for key in path:gmatch("[^%.]+") do
      if type(current) ~= "table" then
        return default
      end
      current = current[key]
      if current == nil then
        return default
      end
    end
    return current
  end,

  ---Format a number with thousands separators
  ---@param value number Number to format
  ---@param sep string? Separator (default: ",")
  ---@return string formatted
  format_number = function(value, sep)
    sep = sep or ","
    local formatted = tostring(math.floor(value))
    local k
    while true do
      formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
      if k == 0 then
        break
      end
    end
    return formatted
  end,

  ---Pad string to specified length
  ---@param value string String to pad
  ---@param length number Target length
  ---@param char string? Pad character (default: " ")
  ---@param side string? "left" or "right" (default: "right")
  ---@return string padded
  pad = function(value, length, char, side)
    char = char or " "
    side = side or "right"
    local str = tostring(value)
    local padding = string.rep(char, math.max(0, length - #str))
    if side == "left" then
      return padding .. str
    else
      return str .. padding
    end
  end,

  ---Trim whitespace from string
  ---@param value string String to trim
  ---@return string trimmed
  trim = function(value)
    if value == nil then
      return ""
    end
    return tostring(value):match("^%s*(.-)%s*$")
  end,

  ---Map function over table values
  ---@param tbl table Table to map over
  ---@param fn function Function to apply to each value
  ---@return table result
  map = function(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
      result[k] = fn(v, k)
    end
    return result
  end,

  ---Filter table by predicate
  ---@param tbl table Table to filter
  ---@param fn function Predicate function (value, key) -> boolean
  ---@return table result
  filter = function(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
      if fn(v, k) then
        result[k] = v
      end
    end
    return result
  end,

  ---Sum values in a table
  ---@param tbl table Table of numbers
  ---@param key string? Key to sum if table of objects
  ---@return number sum
  sum = function(tbl, key)
    local total = 0
    for _, v in pairs(tbl) do
      local val = key and v[key] or v
      total = total + (tonumber(val) or 0)
    end
    return total
  end,

  ---Calculate average of values
  ---@param tbl table Table of numbers
  ---@param key string? Key to average if table of objects
  ---@return number average
  avg = function(tbl, key)
    local total = 0
    local count = 0
    for _, v in pairs(tbl) do
      local val = key and v[key] or v
      total = total + (tonumber(val) or 0)
      count = count + 1
    end
    if count == 0 then
      return 0
    end
    return total / count
  end,

  ---Find min value
  ---@param tbl table Table of numbers
  ---@param key string? Key if table of objects
  ---@return number? min
  min = function(tbl, key)
    local result = nil
    for _, v in pairs(tbl) do
      local val = key and v[key] or v
      val = tonumber(val)
      if val and (result == nil or val < result) then
        result = val
      end
    end
    return result
  end,

  ---Find max value
  ---@param tbl table Table of numbers
  ---@param key string? Key if table of objects
  ---@return number? max
  max = function(tbl, key)
    local result = nil
    for _, v in pairs(tbl) do
      local val = key and v[key] or v
      val = tonumber(val)
      if val and (result == nil or val > result) then
        result = val
      end
    end
    return result
  end,

  ---Group table by key
  ---@param tbl table Table of objects
  ---@param key string Key to group by
  ---@return table<any, table[]> grouped
  group_by = function(tbl, key)
    local result = {}
    for _, v in pairs(tbl) do
      local group_key = v[key]
      if group_key ~= nil then
        result[group_key] = result[group_key] or {}
        table.insert(result[group_key], v)
      end
    end
    return result
  end,

  ---Create lookup table from array
  ---@param tbl table Array of objects
  ---@param key string Key to use as lookup key
  ---@return table<any, table> lookup
  index_by = function(tbl, key)
    local result = {}
    for _, v in pairs(tbl) do
      local lookup_key = v[key]
      if lookup_key ~= nil then
        result[lookup_key] = v
      end
    end
    return result
  end,

  ---Pluck single key from array of objects
  ---@param tbl table Array of objects
  ---@param key string Key to pluck
  ---@return table values
  pluck = function(tbl, key)
    local result = {}
    for _, v in pairs(tbl) do
      table.insert(result, v[key])
    end
    return result
  end,
}
