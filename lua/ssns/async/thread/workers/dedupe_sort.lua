-- Dedupe Sort Worker
-- Deduplicates and sorts columns for completion
-- Pure Lua only - NO vim.* APIs
--
-- Input: { columns }
-- Output: deduplicated and sorted columns with sortText

local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local columns = input.columns or {}

-- Deduplicate by name
local seen = {}
local unique = {}

for _, col in ipairs(columns) do
  local name = col.name or ""
  local key = name:lower()

  if not seen[key] then
    seen[key] = true
    table.insert(unique, col)
  end
end

-- Sort by name
table.sort(unique, function(a, b)
  local a_name = (a.name or ""):lower()
  local b_name = (b.name or ""):lower()
  return a_name < b_name
end)

-- Add sort text for completion
for i, col in ipairs(unique) do
  col.sortText = string.format("%05d_%s", i, col.name or "")
end

-- Send result
async_handle:send(json_encode({
  type = "complete",
  result = { columns = unique },
}))
