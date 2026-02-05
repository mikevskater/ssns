-- Sort Worker
-- Sorts items by a key field
-- Pure Lua only - NO vim.* APIs
--
-- Input: { items, key_field, descending }
-- Output: sorted items with progress updates
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local items = _INPUT.items or {}
local key_field = _INPUT.key_field or "name"
local descending = _INPUT.descending or false

local total = #items

-- Send initial progress
send({
  type = "progress",
  pct = 0,
  message = string.format("Sorting %d items...", total),
})

-- Perform sort
table.sort(items, function(a, b)
  local val_a = a[key_field] or a.name or ""
  local val_b = b[key_field] or b.name or ""

  -- Handle string comparison (case-insensitive)
  if type(val_a) == "string" and type(val_b) == "string" then
    val_a = val_a:lower()
    val_b = val_b:lower()
  end

  if descending then
    return val_a > val_b
  else
    return val_a < val_b
  end
end)

-- Send progress
send({
  type = "progress",
  pct = 50,
  message = "Sort complete, sending results...",
})

-- Send sorted items in batches
local batch_size = 100
local batch = {}

for i, item in ipairs(items) do
  table.insert(batch, {
    idx = item.idx or i,
    name = item.name,
    object_type = item.object_type,
    sort_key = item[key_field],
  })

  if #batch >= batch_size then
    local progress = 50 + math.floor((i / total) * 50)
    send({
      type = "batch",
      items = batch,
      progress = progress,
    })
    batch = {}
  end
end

-- Send remaining batch
if #batch > 0 then
  send({
    type = "batch",
    items = batch,
    progress = 100,
  })
end

-- Send completion
send({
  type = "complete",
  result = { total_sorted = total },
})
