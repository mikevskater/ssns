--- Latency Targets
--- Defines acceptable latency thresholds for async operations
--- Used by regression tests to verify performance requirements
local M = {}

--- Latency targets in milliseconds
--- These are the maximum acceptable times for operations to complete
--- without blocking the UI (16ms = 60fps frame budget)
M.targets = {
  -- File I/O operations
  file_io = {
    read_small = { max_blocking = 5, description = "Read file < 10KB" },
    read_medium = { max_blocking = 10, description = "Read file 10KB-100KB" },
    read_large = { max_blocking = 16, description = "Read file > 100KB should not block" },
    write_small = { max_blocking = 5, description = "Write file < 10KB" },
    write_large = { max_blocking = 16, description = "Write file > 100KB should not block" },
  },

  -- Completion operations
  completion = {
    trigger_response = { max_blocking = 16, description = "Time from trigger to first yield" },
    table_completion = { max_total = 200, description = "Table completion total time" },
    column_completion = { max_total = 200, description = "Column completion total time" },
    schema_completion = { max_total = 150, description = "Schema completion total time" },
  },

  -- Formatting operations
  formatter = {
    small_query = { max_blocking = 50, description = "Format < 10 statements" },
    medium_query = { max_blocking = 100, description = "Format 10-50 statements" },
    large_query = { max_blocking = 16, description = "Format > 50 statements should chunk" },
  },

  -- UI rendering operations
  rendering = {
    tree_render_small = { max_blocking = 16, description = "Render tree < 100 nodes" },
    tree_render_large = { max_blocking = 16, description = "Render tree > 100 nodes should chunk" },
    results_render_small = { max_blocking = 16, description = "Render results < 100 rows" },
    results_render_large = { max_blocking = 16, description = "Render results > 100 rows should chunk" },
    highlight_small = { max_blocking = 10, description = "Apply highlights < 100 lines" },
    highlight_large = { max_blocking = 16, description = "Apply highlights > 100 lines should batch" },
  },

  -- RPC operations (these have network latency, so we measure UI blocking only)
  rpc = {
    connect_start = { max_blocking = 5, description = "Time to start async connect (UI blocking)" },
    load_start = { max_blocking = 5, description = "Time to start async load (UI blocking)" },
  },

  -- Debounced operations
  debounce = {
    search_input = { delay = 150, description = "Search input debounce delay" },
    semantic_highlight = { delay = 50, description = "Semantic highlighting debounce" },
    format_on_save_threshold = { bytes = 50000, description = "Async format threshold" },
  },
}

--- Check if a measured time meets the target
--- @param category string Category (file_io, completion, etc.)
--- @param operation string Operation name
--- @param measured_ms number Measured time in milliseconds
--- @return boolean passes True if meets target
--- @return string? reason Reason if failed
function M.check_target(category, operation, measured_ms)
  local cat = M.targets[category]
  if not cat then
    return false, string.format("Unknown category: %s", category)
  end

  local target = cat[operation]
  if not target then
    return false, string.format("Unknown operation: %s.%s", category, operation)
  end

  local max = target.max_blocking or target.max_total
  if not max then
    return true, nil -- No time target defined
  end

  if measured_ms <= max then
    return true, nil
  else
    return false, string.format(
      "%s.%s exceeded target: %.2fms > %dms (%s)",
      category, operation, measured_ms, max, target.description
    )
  end
end

--- Get all targets for a category
--- @param category string Category name
--- @return table? targets
function M.get_category_targets(category)
  return M.targets[category]
end

--- Generate a markdown report of all latency targets
--- @return string report
function M.generate_targets_report()
  local lines = {
    "# SSNS Async Latency Targets",
    "",
    "These are the performance requirements for async operations.",
    "All UI-blocking operations should complete within 16ms (60fps frame budget).",
    "",
  }

  for category, operations in pairs(M.targets) do
    table.insert(lines, string.format("## %s", category:gsub("_", " "):gsub("^%l", string.upper)))
    table.insert(lines, "")
    table.insert(lines, "| Operation | Target | Description |")
    table.insert(lines, "|-----------|--------|-------------|")

    for op, target in pairs(operations) do
      local target_str
      if target.max_blocking then
        target_str = string.format("≤ %dms blocking", target.max_blocking)
      elseif target.max_total then
        target_str = string.format("≤ %dms total", target.max_total)
      elseif target.delay then
        target_str = string.format("%dms delay", target.delay)
      elseif target.bytes then
        target_str = string.format("> %d bytes", target.bytes)
      else
        target_str = "N/A"
      end

      table.insert(lines, string.format("| %s | %s | %s |", op, target_str, target.description))
    end

    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

--- Verify UI responsiveness during an async operation
--- @param operation_fn function The async operation to run
--- @param timeout_ms number Maximum time to wait
--- @return boolean responsive True if UI remained responsive
--- @return number max_block_time Maximum time between UI checks
function M.verify_ui_responsiveness(operation_fn, timeout_ms)
  timeout_ms = timeout_ms or 5000

  local check_times = {}
  local operation_done = false
  local last_check = vim.loop.hrtime()

  -- Create a timer to check UI responsiveness
  local check_interval = 5 -- Check every 5ms
  local timer = vim.fn.timer_start(check_interval, function()
    local now = vim.loop.hrtime()
    local elapsed = (now - last_check) / 1e6
    table.insert(check_times, elapsed)
    last_check = now
  end, { ["repeat"] = -1 })

  -- Run the operation
  operation_fn(function()
    operation_done = true
  end)

  -- Wait for completion
  local start = vim.loop.hrtime()
  while not operation_done do
    vim.wait(1, function() return operation_done end, 1)
    if (vim.loop.hrtime() - start) / 1e6 > timeout_ms then
      break
    end
  end

  vim.fn.timer_stop(timer)

  -- Analyze results
  local max_block = 0
  for _, t in ipairs(check_times) do
    if t > max_block then
      max_block = t
    end
  end

  -- Consider responsive if max block time < 50ms (allowing some margin)
  local responsive = max_block < 50

  return responsive, max_block
end

return M
