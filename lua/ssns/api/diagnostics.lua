---@class SsnsApiDiagnostics
---Diagnostic and statistics API functions
local M = {}

---Show cache statistics
function M.show_stats()
  local Cache = require('ssns.cache')
  local UiFloat = require('nvim-float.float')
  local ContentBuilder = require('nvim-float.content_builder')
  local stats = Cache.get_stats()

  local cb = ContentBuilder.new()

  cb:header("SSNS Statistics")
  cb:separator("=", 50)
  cb:blank()

  cb:key_value("Servers", stats.server_count)
  cb:key_value("Connected Servers", stats.connected_servers)
  cb:key_value("Total Databases", stats.total_databases)
  cb:key_value("Connected Databases", stats.connected_databases)
  cb:blank()

  cb:section("Servers")
  for _, server_stats in ipairs(stats.servers) do
    local status_style = server_stats.connected and "success" or "error"
    local status_icon = server_stats.connected and "+" or "x"
    cb:spans({
      { text = "  " .. status_icon .. " ", style = status_style },
      { text = server_stats.name, style = "server" },
      { text = " (" },
      { text = server_stats.db_type or "unknown", style = "muted" },
      { text = ") - " },
      { text = tostring(server_stats.database_count), style = "number" },
      { text = " databases" },
    })
  end
  cb:separator("=", 50)

  UiFloat.create_styled(cb, {
    title = "SSNS Statistics",
    min_width = 60,
    footer = "q/Esc: close",
  })
end

---Debug cache contents
function M.debug()
  local Cache = require('ssns.cache')
  Cache.debug_print()
end

---Show completion performance statistics
function M.show_completion_stats()
  local Source = require('ssns.completion.source')
  local UiFloat = require('nvim-float.float')
  local ContentBuilder = require('nvim-float.content_builder')

  -- Try to get stats from the source module
  local success, result = pcall(function()
    local temp_source = Source.new()
    return temp_source:get_stats()
  end)

  if not success then
    vim.notify("SSNS: Failed to get completion stats: " .. tostring(result), vim.log.levels.ERROR)
    return
  end

  local stats = result
  local cb = ContentBuilder.new()

  cb:header("SSNS Completion Performance Statistics")
  cb:separator("=", 50)
  cb:blank()

  cb:key_value("Total Requests", stats.total_requests)
  cb:spans({
    { text = "Average Time: ", style = "label" },
    { text = string.format("%.2fms", stats.avg_time_ms), style = "number" },
  })

  local slow_pct = stats.total_requests > 0 and (stats.slow_requests / stats.total_requests * 100) or 0
  local slow_style = slow_pct > 10 and "warning" or "success"
  cb:spans({
    { text = "Slow Requests (>100ms): ", style = "label" },
    { text = tostring(stats.slow_requests), style = slow_style },
    { text = string.format(" (%.1f%%)", slow_pct), style = "muted" },
  })
  cb:blank()

  cb:spans({
    { text = "Cache Hits: ", style = "label" },
    { text = tostring(stats.cache_hits), style = "success" },
  })
  cb:spans({
    { text = "Cache Misses: ", style = "label" },
    { text = tostring(stats.cache_misses), style = "warning" },
  })

  if stats.cache_hits + stats.cache_misses > 0 then
    local hit_rate = stats.cache_hits / (stats.cache_hits + stats.cache_misses) * 100
    local rate_style = hit_rate > 70 and "success" or (hit_rate > 40 and "warning" or "error")
    cb:spans({
      { text = "Cache Hit Rate: ", style = "label" },
      { text = string.format("%.1f%%", hit_rate), style = rate_style },
    })
  else
    cb:spans({
      { text = "Cache Hit Rate: ", style = "label" },
      { text = "N/A", style = "muted" },
    })
  end
  cb:blank()

  cb:section("Requests by Type")

  -- Sort by request count (descending)
  local types = {}
  for type_name, type_stats in pairs(stats.requests_by_type) do
    table.insert(types, { name = type_name, stats = type_stats })
  end
  table.sort(types, function(a, b)
    return a.stats.count > b.stats.count
  end)

  for _, type_data in ipairs(types) do
    cb:spans({
      { text = "  " },
      { text = type_data.name, style = "emphasis" },
      { text = ": " },
      { text = tostring(type_data.stats.count), style = "number" },
      { text = " requests, avg " },
      { text = string.format("%.2fms", type_data.stats.avg_ms), style = "number" },
    })
  end

  if #types == 0 then
    cb:styled("  (no requests recorded)", "muted")
  end

  cb:blank()
  cb:styled("Note: Stats only tracked when debug mode is enabled", "comment")
  cb:separator("=", 50)

  UiFloat.create_styled(cb, {
    title = "Completion Stats",
    min_width = 70,
    max_width = 70,
    footer = "q/Esc: close",
  })
end

---Reset completion performance statistics
function M.reset_completion_stats()
  local Source = require('ssns.completion.source')

  -- Reset stats through the source module
  local success, err = pcall(function()
    local temp_source = Source.new()
    temp_source:reset_stats()
  end)

  if success then
    vim.notify("SSNS: Completion statistics reset", vim.log.levels.INFO)
  else
    vim.notify("SSNS: Failed to reset completion stats: " .. tostring(err), vim.log.levels.ERROR)
  end
end

---Show usage-based completion statistics
function M.show_usage_stats()
  local UsageTracker = require('ssns.completion.usage_tracker')
  local Cache = require('ssns.cache')
  local UiFloat = require('nvim-float.float')
  local ContentBuilder = require('nvim-float.content_builder')

  -- Get active database
  local active_db = Cache.get_active_database()
  if not active_db then
    vim.notify("No active database connection", vim.log.levels.WARN)
    return
  end

  local server = active_db.parent
  local connection = {
    connection_config = server.connection_config,
    database = active_db.name
  }

  -- Get statistics
  local stats = UsageTracker.get_stats(connection)

  -- Build styled content
  local cb = ContentBuilder.new()

  cb:header("Usage Statistics")
  cb:separator("=", 50)
  cb:blank()

  cb:spans({
    { text = "Connection: ", style = "label" },
    { text = server.name, style = "server" },
  })
  cb:spans({
    { text = "Database: ", style = "label" },
    { text = active_db.name, style = "sql_database" },
  })
  cb:blank()

  cb:key_value("Total Items Tracked", stats.total_items)
  cb:blank()

  cb:section("By Type")
  for type_name, count in pairs(stats.by_type) do
    cb:spans({
      { text = "  " },
      { text = type_name, style = "emphasis" },
      { text = ": " },
      { text = tostring(count), style = "number" },
    })
  end
  cb:blank()

  -- Show top 10 tables
  if stats.top_tables and #stats.top_tables > 0 then
    cb:section("Top 10 Tables")
    for i = 1, math.min(10, #stats.top_tables) do
      local item = stats.top_tables[i]
      cb:spans({
        { text = string.format("  %2d. ", i), style = "muted" },
        { text = item.path, style = "sql_table" },
        { text = " (weight: " },
        { text = tostring(item.weight), style = "number" },
        { text = ")" },
      })
    end
    cb:blank()
  end

  -- Show top 10 columns
  if stats.top_columns and #stats.top_columns > 0 then
    cb:section("Top 10 Columns")
    for i = 1, math.min(10, #stats.top_columns) do
      local item = stats.top_columns[i]
      cb:spans({
        { text = string.format("  %2d. ", i), style = "muted" },
        { text = item.path, style = "sql_column" },
        { text = " (weight: " },
        { text = tostring(item.weight), style = "number" },
        { text = ")" },
      })
    end
    cb:blank()
  end

  -- Show top 10 procedures
  if stats.top_procedures and #stats.top_procedures > 0 then
    cb:section("Top 10 Procedures")
    for i = 1, math.min(10, #stats.top_procedures) do
      local item = stats.top_procedures[i]
      cb:spans({
        { text = string.format("  %2d. ", i), style = "muted" },
        { text = item.path, style = "sql_procedure" },
        { text = " (weight: " },
        { text = tostring(item.weight), style = "number" },
        { text = ")" },
      })
    end
  end

  UiFloat.create_styled(cb, {
    title = "Usage Statistics",
    min_width = 80,
    max_width = 80,
    footer = "q/Esc: close",
  })
end

---Clear all usage weights
function M.clear_usage_weights()
  local UsageTracker = require('ssns.completion.usage_tracker')

  -- Confirm with user
  local confirm = vim.fn.input("Clear ALL usage weights? This cannot be undone. (yes/no): ")
  if confirm:lower() ~= "yes" then
    vim.notify("Cancelled", vim.log.levels.INFO)
    return
  end

  -- Clear all weights
  UsageTracker.clear_weights()
  UsageTracker.save_to_file()

  vim.notify("Usage weights cleared", vim.log.levels.INFO)
end

---Clear usage weights for current connection only
function M.clear_usage_weights_current()
  local UsageTracker = require('ssns.completion.usage_tracker')
  local Cache = require('ssns.cache')

  -- Get active database
  local active_db = Cache.get_active_database()
  if not active_db then
    vim.notify("No active database connection", vim.log.levels.WARN)
    return
  end

  local server = active_db.parent
  local Connections = require('ssns.connections')
  local connection_key = Connections.generate_connection_key(server.connection_config)

  -- Confirm with user
  local confirm = vim.fn.input(string.format("Clear weights for '%s'? (yes/no): ", server.name))
  if confirm:lower() ~= "yes" then
    vim.notify("Cancelled", vim.log.levels.INFO)
    return
  end

  -- Clear weights for this connection
  UsageTracker.clear_weights(connection_key)
  UsageTracker.save_to_file()

  vim.notify(string.format("Usage weights cleared for '%s'", server.name), vim.log.levels.INFO)
end

---Export usage weights to a JSON file
---@param filepath string? Optional file path
function M.export_usage_weights(filepath)
  local UsageTracker = require('ssns.completion.usage_tracker')

  -- Get file path from args or prompt
  local file_path = filepath
  if not file_path or file_path == "" then
    file_path = vim.fn.input("Export to file: ", "", "file")
    if file_path == "" then
      vim.notify("Cancelled", vim.log.levels.INFO)
      return
    end
  end

  -- Expand path
  file_path = vim.fn.expand(file_path)

  -- Check if file exists
  if vim.fn.filereadable(file_path) == 1 then
    local confirm = vim.fn.input(string.format("File '%s' exists. Overwrite? (yes/no): ", file_path))
    if confirm:lower() ~= "yes" then
      vim.notify("Cancelled", vim.log.levels.INFO)
      return
    end
  end

  -- Export (copy current persistence file to target)
  local success, err = pcall(function()
    local source = UsageTracker.persist_file
    local content = vim.fn.readfile(source)
    vim.fn.writefile(content, file_path)
  end)

  if success then
    vim.notify(string.format("Usage weights exported to '%s'", file_path), vim.log.levels.INFO)
  else
    vim.notify(string.format("Export failed: %s", err), vim.log.levels.ERROR)
  end
end

---Import usage weights from a JSON file
---@param filepath string? Optional file path
function M.import_usage_weights(filepath)
  local UsageTracker = require('ssns.completion.usage_tracker')

  -- Get file path from args or prompt
  local file_path = filepath
  if not file_path or file_path == "" then
    file_path = vim.fn.input("Import from file: ", "", "file")
    if file_path == "" then
      vim.notify("Cancelled", vim.log.levels.INFO)
      return
    end
  end

  -- Expand path
  file_path = vim.fn.expand(file_path)

  -- Check if file exists
  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify(string.format("File not found: %s", file_path), vim.log.levels.ERROR)
    return
  end

  -- Confirm merge or replace
  local action = vim.fn.input("Import action: (m)erge or (r)eplace existing weights? (m/r): ")
  if action:lower() ~= "m" and action:lower() ~= "r" then
    vim.notify("Cancelled", vim.log.levels.INFO)
    return
  end

  local merge = (action:lower() == "m")

  -- Import
  local success, err = pcall(function()
    if not merge then
      -- Replace: clear existing first
      UsageTracker.weights = { connections = {} }
    end

    -- Read and decode file
    local content = vim.fn.readfile(file_path)
    local json_str = table.concat(content, "\n")
    local imported_data = vim.json.decode(json_str)

    if not imported_data or not imported_data.connections then
      error("Invalid usage data format")
    end

    -- Merge imported data
    if merge then
      for conn_key, conn_data in pairs(imported_data.connections) do
        if not UsageTracker.weights.connections[conn_key] then
          UsageTracker.weights.connections[conn_key] = conn_data
        else
          -- Merge weights (add them together)
          for type_key, type_data in pairs(conn_data) do
            if not UsageTracker.weights.connections[conn_key][type_key] then
              UsageTracker.weights.connections[conn_key][type_key] = type_data
            else
              for path, weight_data in pairs(type_data) do
                if UsageTracker.weights.connections[conn_key][type_key][path] then
                  -- Add weights together
                  local existing = UsageTracker.weights.connections[conn_key][type_key][path]
                  if type(existing) == "table" and existing.weight then
                    existing.weight = existing.weight + (weight_data.weight or weight_data)
                  else
                    UsageTracker.weights.connections[conn_key][type_key][path] = (existing or 0) + (weight_data.weight or weight_data)
                  end
                else
                  UsageTracker.weights.connections[conn_key][type_key][path] = weight_data
                end
              end
            end
          end
        end
      end
    else
      -- Replace
      UsageTracker.weights = imported_data
    end

    -- Save to file
    UsageTracker.save_to_file()
  end)

  if success then
    local mode_str = merge and "merged" or "replaced"
    vim.notify(string.format("Usage weights %s from '%s'", mode_str, file_path), vim.log.levels.INFO)
  else
    vim.notify(string.format("Import failed: %s", err), vim.log.levels.ERROR)
  end
end

---Toggle usage tracking on/off
function M.toggle_usage_tracking()
  local Config = require('ssns.config')
  local config = Config.get()

  -- Toggle setting
  config.completion.track_usage = not config.completion.track_usage

  -- Notify user
  local status = config.completion.track_usage and "enabled" or "disabled"
  vim.notify(string.format("Usage tracking %s", status), vim.log.levels.INFO)
end

---Toggle semantic highlighting for current buffer
function M.toggle_semantic_highlighting()
  local SemanticHighlighter = require('ssns.highlighting.semantic')
  local bufnr = vim.api.nvim_get_current_buf()

  if SemanticHighlighter.is_enabled(bufnr) then
    SemanticHighlighter.disable_buffer(bufnr)
    vim.notify("Semantic highlighting disabled for this buffer", vim.log.levels.INFO)
  else
    SemanticHighlighter.setup_buffer(bufnr)
    vim.notify("Semantic highlighting enabled for this buffer", vim.log.levels.INFO)
  end
end

return M
