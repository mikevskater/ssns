---FK Graph builder for multi-step JOIN suggestions
---Uses BFS to traverse FK relationships and find related tables
---@class FKGraph
local FKGraph = {}

local Debug = require('nvim-ssns.debug')

---@class FKChainResult
---@field table_obj table TableClass of the target table
---@field hop_count number Distance from source (1, 2, 3)
---@field path table[] Array of intermediate tables traversed
---@field via_table string|nil Name of the table this FK comes through (for display)
---@field constraint table The FK constraint that links to this table

---Build unique key for a table (schema.table or just table)
---@param table_obj table TableClass or table info
---@return string key Unique identifier
local function make_table_key(table_obj)
  local name = table_obj.name or table_obj.table_name or table_obj
  local schema = table_obj.schema or table_obj.schema_name
  if type(name) == "table" then
    name = name.name or tostring(name)
  end
  name = name:lower()
  if schema then
    return schema:lower() .. "." .. name
  end
  return name
end

---Check if a table key is in the path (cycle detection)
---@param key string Table key to check
---@param path table[] Path array
---@return boolean in_path True if key is in path
local function is_in_path(key, path)
  for _, entry in ipairs(path) do
    if entry.key == key then
      return true
    end
  end
  return false
end

---Resolve FK target to actual table object
---@param constraint table ConstraintClass with FK info
---@param connection table Connection context
---@param resolver table Resolver module
---@return table|nil table_obj Resolved TableClass or nil
local function resolve_fk_target(constraint, connection, resolver)
  if not constraint.referenced_table then
    return nil
  end

  -- Build qualified name
  local target_name = constraint.referenced_table
  if constraint.referenced_schema then
    target_name = constraint.referenced_schema .. "." .. target_name
  end

  -- Resolve using metadata resolver
  local table_obj = resolver.resolve_table(target_name, connection, {})
  return table_obj
end

---Get FK constraints from a table
---@param table_obj table TableClass
---@return table[] constraints Array of FK constraints
local function get_fk_constraints(table_obj)
  local constraints = {}

  -- Try to get constraints
  local success, result = pcall(function()
    if table_obj.get_constraints then
      return table_obj:get_constraints()
    elseif table_obj.constraints then
      return table_obj.constraints
    end
    return {}
  end)

  if not success or not result then
    return {}
  end

  -- Filter for FK constraints only
  for _, constraint in ipairs(result) do
    local is_fk = false
    if constraint.constraint_type then
      local ctype = constraint.constraint_type:upper()
      is_fk = ctype:find("FOREIGN") ~= nil or ctype == "FK"
    end
    if is_fk and constraint.referenced_table then
      table.insert(constraints, constraint)
    end
  end

  return constraints
end

---Build FK chain graph from source tables using BFS
---@param source_tables table[] Array of TableClass objects already in query
---@param connection table Connection context with database info
---@param max_depth number Maximum hops to traverse (default 2)
---@return table<number, FKChainResult[]> Results grouped by hop count
function FKGraph.build_chains(source_tables, connection, max_depth)
  max_depth = max_depth or 2
  local Resolver = require('nvim-ssns.completion.metadata.resolver')

  local visited = {}      -- Track visited tables
  local results = {}      -- Group results by hop count
  local queue = {}        -- BFS queue

  -- Initialize results
  for i = 1, max_depth do
    results[i] = {}
  end

  -- Mark source tables as visited (don't suggest them)
  for _, table_obj in ipairs(source_tables) do
    local key = make_table_key(table_obj)
    visited[key] = true

    -- Seed queue with source tables at depth 0
    table.insert(queue, {
      table_obj = table_obj,
      depth = 0,
      path = {},
      source_key = key,
    })
  end

  -- BFS traversal
  while #queue > 0 do
    local current = table.remove(queue, 1)

    -- Don't go deeper than max_depth
    if current.depth >= max_depth then
      goto continue
    end

    -- Get FK constraints for current table
    local constraints = get_fk_constraints(current.table_obj)

    for _, constraint in ipairs(constraints) do
      -- Resolve the FK target table
      local target = resolve_fk_target(constraint, connection, Resolver)

      if target then
        local target_key = make_table_key(target)

        -- Skip if already visited or in current path (cycle)
        if not visited[target_key] and not is_in_path(target_key, current.path) then
          visited[target_key] = true

          -- Build new path including current table
          local new_path = {}
          for _, entry in ipairs(current.path) do
            table.insert(new_path, entry)
          end
          table.insert(new_path, {
            key = make_table_key(current.table_obj),
            table_obj = current.table_obj,
            constraint = constraint,
          })

          -- Determine "via" table for display
          local via_table = nil
          if current.depth > 0 then
            via_table = current.table_obj.name or current.table_obj.table_name
          end

          -- Add to results for this hop count
          local hop_count = current.depth + 1
          table.insert(results[hop_count], {
            table_obj = target,
            hop_count = hop_count,
            path = new_path,
            via_table = via_table,
            constraint = constraint,
            source_table = current.table_obj,
          })

          -- Add to queue for further traversal
          table.insert(queue, {
            table_obj = target,
            depth = hop_count,
            path = new_path,
            source_key = current.source_key,
          })
        end
      end
    end

    ::continue::
  end

  return results
end

---Build FK chain graph from source tables using BFS (async with threading)
---Pre-fetches all constraints and resolves FK targets on main thread,
---then offloads BFS traversal to worker thread
---@param source_tables table[] Array of TableClass objects already in query
---@param connection table Connection context with database info
---@param opts table? Options: {max_depth: number, on_complete: fun(results: table)}
function FKGraph.build_chains_async(source_tables, connection, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 2
  local on_complete = opts.on_complete or function() end

  local Resolver = require('nvim-ssns.completion.metadata.resolver')
  local Thread = require('nvim-ssns.async.thread')

  -- Phase 1: Build serializable graph by pre-fetching all data on main thread
  -- This includes constraints and resolved FK targets

  local graph = {}  -- key -> { table_name, schema_name, constraints: [] }
  local table_objects = {}  -- key -> TableClass (for result mapping)
  local pending_resolutions = 0
  local resolution_complete = false

  -- Helper: Add table to graph if not exists
  local function ensure_table_in_graph(table_obj)
    local key = make_table_key(table_obj)
    if not graph[key] then
      graph[key] = {
        table_name = table_obj.name or table_obj.table_name,
        schema_name = table_obj.schema or table_obj.schema_name,
        constraints = {},
      }
      table_objects[key] = table_obj
    end
    return key
  end

  -- Helper: Process a table's constraints and resolve FK targets
  local function process_table(table_obj, depth)
    if depth >= max_depth then return end

    local key = ensure_table_in_graph(table_obj)
    local constraints = get_fk_constraints(table_obj)

    for _, constraint in ipairs(constraints) do
      if not constraint.referenced_table then goto continue_constraint end

      -- Build target key for lookup
      local target_name = constraint.referenced_table
      if constraint.referenced_schema then
        target_name = constraint.referenced_schema .. "." .. target_name
      end

      -- Add constraint to graph
      table.insert(graph[key].constraints, {
        name = constraint.name or constraint.constraint_name,
        column_name = constraint.columns and constraint.columns[1],
        columns = constraint.columns,
        referenced_table = constraint.referenced_table,
        referenced_schema = constraint.referenced_schema,
        referenced_column = constraint.referenced_columns and constraint.referenced_columns[1],
        referenced_columns = constraint.referenced_columns,
      })

      -- Resolve FK target (may be async in some cases)
      pending_resolutions = pending_resolutions + 1
      local target = resolve_fk_target(constraint, connection, Resolver)

      if target then
        local target_key = ensure_table_in_graph(target)
        -- Recursively process target for deeper hops
        if depth + 1 < max_depth then
          process_table(target, depth + 1)
        end
      end

      pending_resolutions = pending_resolutions - 1

      ::continue_constraint::
    end
  end

  -- Phase 1: Build the graph (sync - uses main thread APIs)
  local source_keys = {}
  for _, table_obj in ipairs(source_tables) do
    local key = ensure_table_in_graph(table_obj)
    table.insert(source_keys, key)
    process_table(table_obj, 0)
  end

  -- Phase 2: Send graph to worker thread for BFS traversal
  Debug.log(string.format("[FK_GRAPH] Starting threaded BFS with %d nodes", vim.tbl_count(graph)))

  local task_id, err = Thread.start({
    worker = "fk_graph",
    input = {
      graph = graph,
      source_keys = source_keys,
      max_depth = max_depth,
      batch_size = 10,
    },
    on_batch = function(batch)
      -- Could stream results here if needed
      Debug.log(string.format("[FK_GRAPH] Batch: %d chains, progress: %d%%",
        #(batch.items or {}), batch.progress or 0))
    end,
    on_progress = function(pct, message)
      Debug.log(string.format("[FK_GRAPH] Progress: %d%% - %s", pct, message or ""))
    end,
    on_complete = function(result, thread_err)
      if thread_err then
        Debug.log(string.format("[FK_GRAPH] Thread error: %s", thread_err))
        on_complete({}, thread_err)
        return
      end

      -- Phase 3: Map worker results back to FKChainResult format with TableClass objects
      local chains = result and result.chains or {}
      local results_by_hop = {}
      for i = 1, max_depth do
        results_by_hop[i] = {}
      end

      for _, chain in ipairs(chains) do
        local target_key = chain.target_schema .. "." .. chain.target_table
        local target_obj = table_objects[target_key:lower()]

        if target_obj then
          local hop_count = chain.depth or 1
          if hop_count >= 1 and hop_count <= max_depth then
            -- Rebuild path with TableClass objects
            local path = {}
            for _, path_key in ipairs(chain.path or {}) do
              local path_obj = table_objects[path_key:lower()]
              if path_obj then
                table.insert(path, {
                  key = path_key,
                  table_obj = path_obj,
                })
              end
            end

            -- Find source table object
            local source_key = chain.source_schema .. "." .. chain.source_table
            local source_obj = table_objects[source_key:lower()]

            table.insert(results_by_hop[hop_count], {
              table_obj = target_obj,
              hop_count = hop_count,
              path = path,
              via_table = chain.source_table,
              constraint = {
                name = chain.constraint_name,
                columns = { chain.source_column },
                referenced_table = chain.target_table,
                referenced_schema = chain.target_schema,
                referenced_columns = { chain.target_column },
              },
              source_table = source_obj,
            })
          end
        end
      end

      Debug.log(string.format("[FK_GRAPH] Thread complete, returning results"))
      on_complete(results_by_hop, nil)
    end,
    timeout_ms = opts.timeout_ms or 30000,
  })

  if not task_id then
    Debug.log(string.format("[FK_GRAPH] Failed to start thread: %s", err or "unknown"))
    on_complete({}, err or "Failed to start FK graph thread")
  end
end

---Build display label for FK chain suggestion
---@param result FKChainResult Chain result
---@return string label Display label like "Countries (via Customers)"
function FKGraph.build_label(result)
  local name = result.table_obj.name or result.table_obj.table_name

  if result.hop_count == 1 then
    return name
  end

  -- Build "via" chain for multi-hop
  local via_parts = {}
  for _, entry in ipairs(result.path) do
    local entry_name = entry.table_obj.name or entry.table_obj.table_obj
    if entry_name then
      table.insert(via_parts, entry_name)
    end
  end

  if #via_parts > 0 then
    -- Show just the immediate predecessor for cleaner display
    local via = via_parts[#via_parts]
    return string.format("%s (via %s)", name, via)
  end

  return name
end

---Build detail string for FK chain suggestion
---@param result FKChainResult Chain result
---@return string detail Detail string
function FKGraph.build_detail(result)
  if result.hop_count == 1 then
    return "JOIN suggestion (FK)"
  end

  return string.format("JOIN suggestion (FK chain: %d hops)", result.hop_count)
end

---Build documentation for FK chain
---@param result FKChainResult Chain result
---@return string doc Markdown documentation
function FKGraph.build_documentation(result)
  local doc_parts = {}

  local target_name = result.table_obj.name or result.table_obj.table_name
  table.insert(doc_parts, string.format("**%s**", target_name))
  table.insert(doc_parts, "")

  if result.hop_count == 1 then
    -- Direct FK
    table.insert(doc_parts, "Direct foreign key relationship")

    if result.constraint then
      local fk_cols = result.constraint.columns or {}
      local ref_cols = result.constraint.referenced_columns or {}
      if #fk_cols > 0 and #ref_cols > 0 then
        table.insert(doc_parts, "")
        table.insert(doc_parts, string.format("FK: %s → %s",
          table.concat(fk_cols, ", "),
          table.concat(ref_cols, ", ")))
      end
    end
  else
    -- Multi-hop FK chain
    table.insert(doc_parts, string.format("FK chain (%d hops)", result.hop_count))
    table.insert(doc_parts, "")

    -- Build path description
    local path_names = {}
    for _, entry in ipairs(result.path) do
      local name = entry.table_obj.name or entry.table_obj.table_name
      if name then
        table.insert(path_names, name)
      end
    end
    table.insert(path_names, target_name)

    if #path_names > 1 then
      table.insert(doc_parts, "Path: " .. table.concat(path_names, " → "))
    end
  end

  return table.concat(doc_parts, "\n")
end

---Get all FK chain results as flat array sorted by hop count
---@param chain_results table<number, FKChainResult[]> Results from build_chains
---@return FKChainResult[] sorted Flat sorted array
function FKGraph.flatten_and_sort(chain_results)
  local flat = {}

  for hop_count = 1, 3 do
    local hop_results = chain_results[hop_count] or {}
    for _, result in ipairs(hop_results) do
      table.insert(flat, result)
    end
  end

  return flat
end

return FKGraph
