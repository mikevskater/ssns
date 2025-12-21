-- Dedupe Sort Worker
-- Deduplicates and sorts columns for completion with weight-based priority
-- Pure Lua only - NO vim.* APIs
--
-- Input: {
--   columns = { { name, is_primary_key, weight, table_name, data_type, ... }, ... }
-- }
-- Output: {
--   columns = { { name, sortText, priority, ... }, ... }
-- }
--
-- Priority order:
-- 1. Primary keys (priority 1-99, sorted by weight)
-- 2. High-weight columns (priority 1000-4999, sorted by weight desc)
-- 3. No-weight columns (priority 5000+, sorted by ordinal then name)
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

-- Deduplicate by name, tracking max weight per column
local seen = {}
local unique = {}
local max_weights = {}  -- Track max weight for each column name

for i, col in ipairs(columns) do
  local name = col.name or ""
  local key = name:lower()
  local weight = col.weight or 0

  if not seen[key] then
    seen[key] = true
    max_weights[key] = weight
    table.insert(unique, col)
  else
    -- Track max weight across all occurrences
    if weight > (max_weights[key] or 0) then
      max_weights[key] = weight
    end
  end

  -- Progress every 25%
  if i % math.max(1, math.floor(total / 4)) == 0 then
    send({
      type = "progress",
      pct = math.floor((i / total) * 40),
      message = string.format("Processed %d/%d columns...", i, total),
    })
  end
end

send({
  type = "progress",
  pct = 40,
  message = string.format("Computing priorities for %d columns...", #unique),
})

-- Compute priority for each column
for i, col in ipairs(unique) do
  local name = col.name or ""
  local key = name:lower()
  local weight = max_weights[key] or 0
  local is_pk = col.is_primary_key
  local ordinal = 999  -- Default ordinal for deduplicated columns

  local priority
  if is_pk then
    -- Primary keys: priority 1-99 (lower weight = higher priority)
    priority = 100 - math.min(weight, 99)
  elseif weight > 0 then
    -- Weighted columns: priority 1000-4999 (higher weight = lower priority number = higher rank)
    priority = 1000 + math.max(0, 3999 - weight)
  else
    -- No-weight columns: priority 5000+
    priority = 5000 + ordinal
  end

  col.priority = priority
  col.computed_weight = weight
end

send({
  type = "progress",
  pct = 60,
  message = string.format("Sorting %d unique columns...", #unique),
})

-- Sort by priority, then by name for stable ordering
table.sort(unique, function(a, b)
  if a.priority ~= b.priority then
    return a.priority < b.priority
  end
  local a_name = (a.name or ""):lower()
  local b_name = (b.name or ""):lower()
  return a_name < b_name
end)

send({
  type = "progress",
  pct = 80,
  message = "Adding sort text...",
})

-- Add sortText for blink.cmp ordering
for i, col in ipairs(unique) do
  local name = col.name or ""
  local priority = col.priority or 5000
  local ordinal = 999
  col.sortText = string.format("%05d_%04d_%s", priority, ordinal, name)
end

send({
  type = "progress",
  pct = 100,
  message = "Complete",
})

-- Send result
send({
  type = "complete",
  result = { columns = unique },
})
