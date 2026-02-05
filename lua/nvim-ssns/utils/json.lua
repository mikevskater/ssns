---@class JsonUtils
---JSON utility functions for pretty-printing and formatting
---@module ssns.utils.json
local JsonUtils = {}

---Prettify a Lua table into a formatted JSON-like string
---@param value any The value to prettify
---@param indent number? Current indentation level (default: 0)
---@param indent_str string? Indentation string (default: "  ")
---@return string formatted The prettified string
function JsonUtils.prettify(value, indent, indent_str)
  indent = indent or 0
  indent_str = indent_str or "  "

  local t = type(value)

  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return tostring(value)
  elseif t == "number" then
    return tostring(value)
  elseif t == "string" then
    -- Escape special characters
    local escaped = value:gsub('\\', '\\\\')
      :gsub('"', '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')
    return '"' .. escaped .. '"'
  elseif t == "table" then
    -- Check if array (sequential numeric keys starting at 1)
    local is_array = true
    local max_index = 0
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        is_array = false
        break
      end
      if k > max_index then
        max_index = k
      end
    end

    -- Also check for holes in array
    if is_array and max_index > 0 then
      for i = 1, max_index do
        if value[i] == nil then
          is_array = false
          break
        end
      end
    end

    -- Empty table
    if next(value) == nil then
      return is_array and "[]" or "{}"
    end

    local prefix = string.rep(indent_str, indent)
    local inner_prefix = string.rep(indent_str, indent + 1)
    local parts = {}

    if is_array then
      for i = 1, max_index do
        table.insert(parts, inner_prefix .. JsonUtils.prettify(value[i], indent + 1, indent_str))
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. prefix .. "]"
    else
      -- Sort keys for consistent output
      local keys = {}
      for k in pairs(value) do
        table.insert(keys, k)
      end
      table.sort(keys, function(a, b)
        -- Sort numbers before strings, then alphabetically
        local ta, tb = type(a), type(b)
        if ta ~= tb then
          return ta < tb
        end
        return tostring(a) < tostring(b)
      end)

      for _, k in ipairs(keys) do
        local key_str = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
        local val_str = JsonUtils.prettify(value[k], indent + 1, indent_str)
        table.insert(parts, inner_prefix .. key_str .. ": " .. val_str)
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. prefix .. "}"
    end
  elseif t == "function" then
    return '"<function>"'
  elseif t == "userdata" then
    return '"<userdata>"'
  elseif t == "thread" then
    return '"<thread>"'
  else
    return '"<' .. t .. '>"'
  end
end

---Convert prettified JSON string to array of lines
---@param json_str string The prettified JSON string
---@return string[] lines Array of lines
function JsonUtils.to_lines(json_str)
  local lines = {}
  for line in json_str:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  -- Handle case where string is empty or ends with newline
  if #lines == 0 then
    table.insert(lines, json_str)
  end
  return lines
end

---Prettify a value and return as array of lines
---@param value any The value to prettify
---@param indent_str string? Indentation string (default: "  ")
---@return string[] lines Array of formatted lines
function JsonUtils.prettify_lines(value, indent_str)
  local json_str = JsonUtils.prettify(value, 0, indent_str)
  return JsonUtils.to_lines(json_str)
end

return JsonUtils
