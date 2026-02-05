-- FK Graph Worker
-- BFS traversal for foreign key chain discovery
-- Pure Lua only - NO vim.* APIs
--
-- Input: { graph, source_keys, max_depth, batch_size }
-- Output: batches of FK chains with completion summary
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local graph = _INPUT.graph or {}
local source_keys = _INPUT.source_keys or {}
local max_depth = _INPUT.max_depth or 2
local batch_size = _INPUT.batch_size or 10

-- BFS traversal
local queue = {}
local visited = {}
local chains = {}
local batch = {}

-- Count total nodes for progress
local total_nodes = 0
for _ in pairs(graph) do total_nodes = total_nodes + 1 end

send({
  type = "progress",
  pct = 0,
  message = string.format("Traversing FK graph (%d nodes)...", total_nodes),
})

-- Initialize queue with source tables
for _, key in ipairs(source_keys) do
  if graph[key] then
    table.insert(queue, {
      key = key,
      path = { key },
      depth = 0,
    })
  end
end

local processed = 0

while #queue > 0 do
  local current = table.remove(queue, 1)
  processed = processed + 1

  if current.depth >= max_depth then
    goto continue
  end

  local node = graph[current.key]
  if not node then
    goto continue
  end

  -- Process constraints
  for _, constraint in ipairs(node.constraints or {}) do
    local target_key = constraint.referenced_schema .. "." .. constraint.referenced_table

    if not visited[current.key .. "->" .. target_key] then
      visited[current.key .. "->" .. target_key] = true

      -- Build chain
      local chain = {
        source_table = node.table_name,
        source_schema = node.schema_name,
        source_column = constraint.column_name,
        target_table = constraint.referenced_table,
        target_schema = constraint.referenced_schema,
        target_column = constraint.referenced_column,
        constraint_name = constraint.name,
        depth = current.depth + 1,
        path = current.path,
      }

      table.insert(batch, chain)
      table.insert(chains, chain)

      -- Send batch
      if #batch >= batch_size then
        send({
          type = "batch",
          items = batch,
          progress = math.min(90, math.floor((processed / math.max(1, #source_keys * 10)) * 90)),
        })
        batch = {}
      end

      -- Continue BFS if target exists in graph
      if graph[target_key] then
        local new_path = {}
        for _, p in ipairs(current.path) do
          table.insert(new_path, p)
        end
        table.insert(new_path, target_key)

        table.insert(queue, {
          key = target_key,
          path = new_path,
          depth = current.depth + 1,
        })
      end
    end
  end

  ::continue::
end

-- Send remaining batch
if #batch > 0 then
  send({
    type = "batch",
    items = batch,
    progress = 95,
  })
end

-- Send completion
send({
  type = "complete",
  result = { chains = chains, total = #chains },
})
