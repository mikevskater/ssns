-- Sort Worker
-- Sorts items by a key field
-- Pure Lua only - NO vim.* APIs
--
-- Input: { items, key_field, descending }
-- Output: sorted items array

local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local items = input.items or {}
local key_field = input.key_field or "name"
local descending = input.descending or false

-- Sort items
table.sort(items, function(a, b)
  local a_key = a[key_field] or a.sort_key or a.name or ""
  local b_key = b[key_field] or b.sort_key or b.name or ""

  -- Case-insensitive string comparison
  if type(a_key) == "string" and type(b_key) == "string" then
    a_key = a_key:lower()
    b_key = b_key:lower()
  end

  if descending then
    return a_key > b_key
  else
    return a_key < b_key
  end
end)

-- Send sorted result
async_handle:send(json_encode({
  type = "complete",
  result = { items = items },
}))
