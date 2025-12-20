-- Dedupe Sort Worker
-- Deduplicates and sorts columns for completion
-- Pure Lua only - NO vim.* APIs
--
-- Input: { columns }
-- Output: deduplicated and sorted columns with sortText
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local columns = _INPUT.columns or {}
local total = #columns

-- Send initial progress
send({
  type = "progress",
  pct = 0,
  message = string.format("Deduplicating %d columns...", total),
})

-- Deduplicate by name
local seen = {}
local unique = {}

for i, col in ipairs(columns) do
  local name = col.name or ""
  local key = name:lower()

  if not seen[key] then
    seen[key] = true
    table.insert(unique, col)
  end

  -- Progress every 25%
  if i % math.max(1, math.floor(total / 4)) == 0 then
    send({
      type = "progress",
      pct = math.floor((i / total) * 50),
      message = string.format("Processed %d/%d columns...", i, total),
    })
  end
end

send({
  type = "progress",
  pct = 50,
  message = string.format("Sorting %d unique columns...", #unique),
})

-- Sort by name
table.sort(unique, function(a, b)
  local a_name = (a.name or ""):lower()
  local b_name = (b.name or ""):lower()
  return a_name < b_name
end)

send({
  type = "progress",
  pct = 75,
  message = "Adding sort indices...",
})

-- Add sort text for completion
for i, col in ipairs(unique) do
  col.sortText = string.format("%05d_%s", i, col.name or "")
end

-- Send result
send({
  type = "complete",
  result = { columns = unique },
})
