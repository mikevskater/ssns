---@class Ssns
---SQL Server NeoVim Studio
---A pure Lua Neovim plugin for database management with SSMS-style UI
local Ssns = {}

---Plugin version
Ssns.version = "0.1.0-dev"

---Setup the plugin
---@param user_config SsnsConfig? User configuration
function Ssns.setup(user_config)
  -- Load configuration
  local Config = require('ssns.config')

  -- Validate user config if provided
  if user_config then
    local valid, err = Config.validate(user_config)
    if not valid then
      vim.notify(string.format("SSNS: Invalid configuration: %s", err), vim.log.levels.ERROR)
      return
    end
  end

  -- Setup configuration
  Config.setup(user_config)

  -- Load servers from configuration
  local Cache = require('ssns.cache')
  local servers, errors = Cache.load_from_config(Config.get())

  -- Report any connection errors
  if vim.tbl_count(errors) > 0 then
    for name, error_msg in pairs(errors) do
      vim.notify(
        string.format("SSNS: Failed to create connection '%s': %s", name, error_msg),
        vim.log.levels.WARN
      )
    end
  end

  -- Report successful initialization
  if #servers > 0 then
    vim.notify(
      string.format("SSNS: Initialized with %d connection(s)", #servers),
      vim.log.levels.INFO
    )
  end

  -- Setup UI highlights
  local Highlights = require('ssns.ui.highlights')
  Highlights.setup()
  Highlights.setup_filetype()

  -- Setup semantic highlighting for SQL query buffers
  local SemanticHighlighter = require('ssns.highlighting.semantic')
  SemanticHighlighter.setup()

  -- Initialize query history
  local QueryHistory = require('ssns.query_history')
  local config = Config.get()
  QueryHistory.max_buffers = config.query_history.max_buffers
  QueryHistory.max_entries_per_buffer = config.query_history.max_entries_per_buffer
  QueryHistory.auto_persist = config.query_history.auto_persist
  QueryHistory.persist_file = config.query_history.persist_file
  QueryHistory.exclude_patterns = config.query_history.exclude_patterns
  if config.query_history.enabled then
    QueryHistory.init()
  end

  -- Register commands
  Ssns._register_commands()

  -- Setup expand asterisk keymap for SQL buffers
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "sql",
    callback = function(args)
      local bufnr = args.buf
      vim.keymap.set('n', '<Leader>ce', function()
        local ExpandAsterisk = require('ssns.features.expand_asterisk')
        ExpandAsterisk.expand_asterisk_at_cursor()
      end, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Expand asterisk (Columns Expand)'
      })

      -- Enable semantic highlighting for SQL files
      local sh_config = Config.get_semantic_highlighting()
      if sh_config.enabled then
        local SemanticHighlighter = require('ssns.highlighting.semantic')
        SemanticHighlighter.setup_buffer(bufnr)
      end
    end,
  })
end

---Register Neovim commands
function Ssns._register_commands()
  -- :SSNS - Toggle the tree UI
  vim.api.nvim_create_user_command("SSNS", function()
    Ssns.toggle()
  end, {
    desc = "Toggle SSNS database tree",
  })

  -- :SSNSOpen - Open the tree UI
  vim.api.nvim_create_user_command("SSNSOpen", function()
    Ssns.open()
  end, {
    desc = "Open SSNS database tree",
  })

  -- :SSNSClose - Close the tree UI
  vim.api.nvim_create_user_command("SSNSClose", function()
    Ssns.close()
  end, {
    desc = "Close SSNS database tree",
  })

  -- :SSNSFloat - Open tree UI in floating window mode
  vim.api.nvim_create_user_command("SSNSFloat", function()
    Ssns.open_float()
  end, {
    desc = "Open SSNS database tree in floating window",
  })

  -- :SSNSDocked - Open tree UI in docked/split mode
  vim.api.nvim_create_user_command("SSNSDocked", function()
    Ssns.open_docked()
  end, {
    desc = "Open SSNS database tree in docked split",
  })

  -- :SSNSRefresh - Refresh all servers
  vim.api.nvim_create_user_command("SSNSRefresh", function()
    Ssns.refresh_all()
  end, {
    desc = "Refresh all SSNS servers",
  })

  -- :SSNSConnect <name> - Connect to a saved connection
  vim.api.nvim_create_user_command("SSNSConnect", function(opts)
    Ssns.connect(opts.args)
  end, {
    nargs = 1,
    desc = "Connect to a saved SSNS connection",
    complete = function()
      local Config = require('ssns.config')
      local connections = Config.get_connections()
      local names = {}
      for name, _ in pairs(connections) do
        table.insert(names, name)
      end
      return names
    end,
  })

  -- :SSNSQuery - Open a new query buffer
  vim.api.nvim_create_user_command("SSNSQuery", function()
    Ssns.new_query()
  end, {
    desc = "Open a new SSNS query buffer",
  })

  -- :SSNSStats - Show cache statistics
  vim.api.nvim_create_user_command("SSNSStats", function()
    Ssns.show_stats()
  end, {
    desc = "Show SSNS cache statistics",
  })

  -- :SSNSDebug - Debug cache contents
  vim.api.nvim_create_user_command("SSNSDebug", function()
    Ssns.debug()
  end, {
    desc = "Debug SSNS cache contents",
  })

  -- :SSNSHistory - Show query history
  vim.api.nvim_create_user_command("SSNSHistory", function()
    Ssns.show_history()
  end, {
    desc = "Show query execution history",
  })

  -- :SSNSHistoryClear - Clear query history
  vim.api.nvim_create_user_command("SSNSHistoryClear", function()
    Ssns.clear_history()
  end, {
    desc = "Clear all query history",
  })

  -- :SSNSHistoryExport - Export query history
  vim.api.nvim_create_user_command("SSNSHistoryExport", function(opts)
    Ssns.export_history(opts.args)
  end, {
    nargs = "?",
    desc = "Export query history to file",
    complete = "file",
  })

  -- :SSNSCompletionStats - Show completion performance statistics
  vim.api.nvim_create_user_command("SSNSCompletionStats", function()
    Ssns.show_completion_stats()
  end, {
    desc = "Show completion performance statistics",
  })

  -- :SSNSCompletionStatsReset - Reset completion performance statistics
  vim.api.nvim_create_user_command("SSNSCompletionStatsReset", function()
    Ssns.reset_completion_stats()
  end, {
    desc = "Reset completion performance statistics",
  })

  -- :SSNSExpandAsterisk - Expand * or alias.* to column list
  vim.api.nvim_create_user_command("SSNSExpandAsterisk", function()
    local ExpandAsterisk = require('ssns.features.expand_asterisk')
    ExpandAsterisk.expand_asterisk_at_cursor()
  end, {
    nargs = 0,
    desc = "Expand * or alias.* to column list (like SSMS RedGate)",
  })

  -- :SSNSUsageStats - Display usage statistics for the current connection
  vim.api.nvim_create_user_command("SSNSUsageStats", function()
    Ssns.show_usage_stats()
  end, {
    nargs = 0,
    desc = "Show usage-based completion statistics",
  })

  -- :SSNSUsageClear - Clear all usage weights
  vim.api.nvim_create_user_command("SSNSUsageClear", function()
    Ssns.clear_usage_weights()
  end, {
    nargs = 0,
    desc = "Clear all usage weights (requires confirmation)",
  })

  -- :SSNSUsageClearCurrent - Clear weights for current connection only
  vim.api.nvim_create_user_command("SSNSUsageClearCurrent", function()
    Ssns.clear_usage_weights_current()
  end, {
    nargs = 0,
    desc = "Clear usage weights for current connection (requires confirmation)",
  })

  -- :SSNSUsageExport - Export weights to a JSON file
  vim.api.nvim_create_user_command("SSNSUsageExport", function(opts)
    Ssns.export_usage_weights(opts.args)
  end, {
    nargs = "?",
    desc = "Export usage weights to JSON file",
    complete = "file",
  })

  -- :SSNSUsageImport - Import weights from a JSON file
  vim.api.nvim_create_user_command("SSNSUsageImport", function(opts)
    Ssns.import_usage_weights(opts.args)
  end, {
    nargs = "?",
    desc = "Import usage weights from JSON file",
    complete = "file",
  })

  -- :SSNSUsageToggle - Toggle usage tracking on/off
  vim.api.nvim_create_user_command("SSNSUsageToggle", function()
    Ssns.toggle_usage_tracking()
  end, {
    nargs = 0,
    desc = "Toggle usage tracking on/off",
  })

  -- :SSNSHighlightToggle - Toggle semantic highlighting on/off for current buffer
  vim.api.nvim_create_user_command("SSNSHighlightToggle", function()
    Ssns.toggle_semantic_highlighting()
  end, {
    nargs = 0,
    desc = "Toggle semantic highlighting for current buffer",
  })

  -- Testing Framework Commands

  -- :SSNSRunTests - Run all IntelliSense tests
  vim.api.nvim_create_user_command("SSNSRunTests", function()
    Ssns.run_all_tests()
  end, {
    nargs = 0,
    desc = "Run all SSNS IntelliSense tests",
  })

  -- :SSNSRunTest <number> - Run a specific test by number
  vim.api.nvim_create_user_command("SSNSRunTest", function(opts)
    local test_number = tonumber(opts.args)
    if not test_number then
      vim.notify("Invalid test number. Usage: :SSNSRunTest <number>", vim.log.levels.ERROR)
      return
    end
    Ssns.run_test(test_number)
  end, {
    nargs = 1,
    desc = "Run a specific SSNS test by number (1-40)",
  })

  -- :SSNSRunTestCategory <category> - Run tests in a specific category
  vim.api.nvim_create_user_command("SSNSRunTestCategory", function(opts)
    Ssns.run_category_tests(opts.args)
  end, {
    nargs = 1,
    desc = "Run tests in a specific category folder",
    complete = function()
      -- Get list of category folders from the tests directory
      local tests_path = vim.fn.stdpath("config") .. "/lua/ssns/testing/tests"
      local categories = {}

      local handle = vim.loop.fs_scandir(tests_path)
      if handle then
        while true do
          local name, type = vim.loop.fs_scandir_next(handle)
          if not name then break end
          if type == "directory" then
            table.insert(categories, name)
          end
        end
      end

      table.sort(categories)
      return categories
    end,
  })

  -- :SSNSRunTestsByType <type> - Run tests by completion type
  vim.api.nvim_create_user_command("SSNSRunTestsByType", function(opts)
    Ssns.run_tests_by_type(opts.args)
  end, {
    nargs = 1,
    desc = "Run tests by completion type (table, column, schema, etc.)",
    complete = function()
      -- Return common completion types
      return {
        "table",
        "column",
        "schema",
        "object",
        "database",
        "function",
        "procedure",
        "view",
      }
    end,
  })

  -- :SSNSViewTestResults - Open test results markdown file
  vim.api.nvim_create_user_command("SSNSViewTestResults", function()
    Ssns.view_test_results()
  end, {
    nargs = 0,
    desc = "Open the test results markdown file",
  })
end

---Toggle the tree UI
function Ssns.toggle()
  local Buffer = require('ssns.ui.buffer')
  local Tree = require('ssns.ui.tree')

  Buffer.toggle()

  -- If window was opened, render the tree
  if Buffer.is_open() then
    Tree.render()
  end
end

---Open the tree UI
---@param mode_override string? Optional mode override: "float" or "docked"
function Ssns.open(mode_override)
  local Buffer = require('ssns.ui.buffer')
  local Tree = require('ssns.ui.tree')

  Buffer.open(mode_override)
  Tree.render()
end

---Open the tree UI in floating window mode (regardless of config)
function Ssns.open_float()
  Ssns.open("float")
end

---Open the tree UI in docked/split mode (regardless of config)
function Ssns.open_docked()
  Ssns.open("docked")
end

---Close the tree UI
function Ssns.close()
  local Buffer = require('ssns.ui.buffer')
  Buffer.close()
end

---Refresh all servers
function Ssns.refresh_all()
  local Cache = require('ssns.cache')
  Cache.refresh_all()
  vim.notify("SSNS: Refreshed all servers", vim.log.levels.INFO)
end

---Connect to a saved connection
---@param connection_name string
function Ssns.connect(connection_name)
  local Config = require('ssns.config')
  local Cache = require('ssns.cache')

  -- Check if already in cache
  local existing_server = Cache.find_server(connection_name)
  if existing_server then
    local success, err = existing_server:connect()
    if success then
      vim.notify(string.format("SSNS: Connected to '%s'", connection_name), vim.log.levels.INFO)
    else
      vim.notify(string.format("SSNS: Failed to connect to '%s': %s", connection_name, err), vim.log.levels.ERROR)
    end
    return
  end

  -- Get connection string from config
  local connections = Config.get_connections()
  local connection_string = connections[connection_name]

  if not connection_string then
    vim.notify(string.format("SSNS: Connection '%s' not found in configuration", connection_name), vim.log.levels.ERROR)
    return
  end

  -- Create and add server
  local Factory = require('ssns.factory')
  local server, err = Factory.create_server_from_config(connection_name, connection_string)

  if not server then
    vim.notify(string.format("SSNS: Failed to create connection '%s': %s", connection_name, err), vim.log.levels.ERROR)
    return
  end

  Cache.add_server(server)

  -- Connect
  local success, connect_err = server:connect()
  if success then
    vim.notify(string.format("SSNS: Connected to '%s'", connection_name), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Failed to connect to '%s': %s", connection_name, connect_err), vim.log.levels.ERROR)
  end
end

---Open a new query buffer
function Ssns.new_query()
  local Query = require('ssns.ui.query')
  local Cache = require('ssns.cache')

  -- Get all servers
  local servers = Cache.get_all_servers()

  if #servers == 0 then
    vim.notify("SSNS: No servers configured", vim.log.levels.WARN)
    return
  end

  -- If only one server, use it directly
  if #servers == 1 then
    Query.create_query_buffer(servers[1], nil, nil)
    return
  end

  -- Multiple servers - prompt user to select
  local server_names = {}
  for _, server in ipairs(servers) do
    table.insert(server_names, server.name)
  end

  vim.ui.select(server_names, {
    prompt = "Select server:",
  }, function(choice, idx)
    if choice then
      Query.create_query_buffer(servers[idx], nil, nil)
    end
  end)
end

---Show cache statistics
function Ssns.show_stats()
  local Cache = require('ssns.cache')
  local stats = Cache.get_stats()

  local lines = {
    "=== SSNS Statistics ===",
    string.format("Servers: %d", stats.server_count),
    string.format("Connected Servers: %d", stats.connected_servers),
    string.format("Total Databases: %d", stats.total_databases),
    string.format("Connected Databases: %d", stats.connected_databases),
    "",
    "Servers:",
  }

  for _, server_stats in ipairs(stats.servers) do
    local status = server_stats.connected and "✓" or "✗"
    table.insert(
      lines,
      string.format("  %s %s (%s) - %d databases", status, server_stats.name, server_stats.db_type or "unknown", server_stats.database_count)
    )
  end

  table.insert(lines, "======================")

  -- Display in a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 60
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { noremap = true, silent = true })
end

---Debug cache contents
function Ssns.debug()
  local Cache = require('ssns.cache')
  Cache.debug_print()
end

---Show query history
function Ssns.show_history()
  local UiHistory = require('ssns.ui.history')
  UiHistory.show_history()
end

---Clear query history
function Ssns.clear_history()
  local QueryHistory = require('ssns.query_history')
  QueryHistory.clear_all()
end

---Export query history
---@param filepath string? Optional file path
function Ssns.export_history(filepath)
  local QueryHistory = require('ssns.query_history')

  if not filepath or filepath == "" then
    filepath = vim.fn.stdpath('data') .. '/ssns/history_export.txt'
  end

  local format = filepath:match("%.([^.]+)$")
  if format == "json" then
    format = "json"
  else
    format = "txt"
  end

  if QueryHistory.export(filepath, format) then
    vim.notify("History exported to " .. filepath, vim.log.levels.INFO)
  end
end

---Get current version
---@return string version
function Ssns.get_version()
  return Ssns.version
end

---Get cache instance (for advanced usage)
---@return Cache
function Ssns.get_cache()
  return require('ssns.cache')
end

---Get factory instance (for advanced usage)
---@return Factory
function Ssns.get_factory()
  return require('ssns.factory')
end

---Get config instance (for advanced usage)
---@return Config
function Ssns.get_config()
  return require('ssns.config')
end

---Show completion performance statistics
function Ssns.show_completion_stats()
  local Source = require('ssns.completion.source')

  -- Try to get stats from the source module
  -- Note: This accesses the module-level stats through the Source class
  local success, result = pcall(function()
    -- Create a temporary source instance to access the get_stats method
    local temp_source = Source.new()
    return temp_source:get_stats()
  end)

  if not success then
    vim.notify("SSNS: Failed to get completion stats: " .. tostring(result), vim.log.levels.ERROR)
    return
  end

  local stats = result

  local lines = {
    "=== SSNS Completion Performance Statistics ===",
    "",
    string.format("Total Requests: %d", stats.total_requests),
    string.format("Average Time: %.2fms", stats.avg_time_ms),
    string.format(
      "Slow Requests (>100ms): %d (%.1f%%)",
      stats.slow_requests,
      stats.total_requests > 0 and (stats.slow_requests / stats.total_requests * 100) or 0
    ),
    "",
    string.format("Cache Hits: %d", stats.cache_hits),
    string.format("Cache Misses: %d", stats.cache_misses),
    stats.cache_hits + stats.cache_misses > 0
        and string.format(
          "Cache Hit Rate: %.1f%%",
          (stats.cache_hits / (stats.cache_hits + stats.cache_misses) * 100)
        )
      or "Cache Hit Rate: N/A",
    "",
    "Requests by Type:",
  }

  -- Sort by request count (descending)
  local types = {}
  for type_name, type_stats in pairs(stats.requests_by_type) do
    table.insert(types, { name = type_name, stats = type_stats })
  end
  table.sort(types, function(a, b)
    return a.stats.count > b.stats.count
  end)

  for _, type_data in ipairs(types) do
    table.insert(
      lines,
      string.format(
        "  %s: %d requests, avg %.2fms",
        type_data.name,
        type_data.stats.count,
        type_data.stats.avg_ms
      )
    )
  end

  if #types == 0 then
    table.insert(lines, "  (no requests recorded)")
  end

  table.insert(lines, "")
  table.insert(lines, "Note: Stats only tracked when debug mode is enabled")
  table.insert(lines, "===============================================")

  -- Display in a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(70, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Completion Stats ",
    title_pos = "center",
  })

  -- Set buffer options
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { noremap = true, silent = true })
end

---Reset completion performance statistics
function Ssns.reset_completion_stats()
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
function Ssns.show_usage_stats()
  local UsageTracker = require('ssns.completion.usage_tracker')
  local Cache = require('ssns.cache')

  -- Get active database
  local active_db = Cache.get_active_database()
  if not active_db then
    vim.notify("No active database connection", vim.log.levels.WARN)
    return
  end

  local server = active_db.parent
  local connection = {
    connection_string = server.connection_string,
    database = active_db.name
  }

  -- Get statistics
  local stats = UsageTracker.get_stats(connection)

  -- Format output
  local lines = {}
  table.insert(lines, "=== Usage Statistics ===")
  table.insert(lines, string.format("Connection: %s", server.name))
  table.insert(lines, string.format("Database: %s", active_db.name))
  table.insert(lines, "")
  table.insert(lines, string.format("Total Items Tracked: %d", stats.total_items))
  table.insert(lines, "")
  table.insert(lines, "By Type:")
  for type_name, count in pairs(stats.by_type) do
    table.insert(lines, string.format("  %s: %d", type_name, count))
  end
  table.insert(lines, "")

  -- Show top 10 tables
  if stats.top_tables and #stats.top_tables > 0 then
    table.insert(lines, "Top 10 Tables:")
    for i = 1, math.min(10, #stats.top_tables) do
      local item = stats.top_tables[i]
      table.insert(lines, string.format("  %2d. %s (weight: %d)", i, item.path, item.weight))
    end
    table.insert(lines, "")
  end

  -- Show top 10 columns
  if stats.top_columns and #stats.top_columns > 0 then
    table.insert(lines, "Top 10 Columns:")
    for i = 1, math.min(10, #stats.top_columns) do
      local item = stats.top_columns[i]
      table.insert(lines, string.format("  %2d. %s (weight: %d)", i, item.path, item.weight))
    end
    table.insert(lines, "")
  end

  -- Show top 10 procedures
  if stats.top_procedures and #stats.top_procedures > 0 then
    table.insert(lines, "Top 10 Procedures:")
    for i = 1, math.min(10, #stats.top_procedures) do
      local item = stats.top_procedures[i]
      table.insert(lines, string.format("  %2d. %s (weight: %d)", i, item.path, item.weight))
    end
  end

  -- Display in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'ssns-usage-stats', { buf = buf })

  local width = 80
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Usage Statistics ',
    title_pos = 'center'
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Close on q or <Esc>
  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, nowait = true })
end

---Clear all usage weights
function Ssns.clear_usage_weights()
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
function Ssns.clear_usage_weights_current()
  local UsageTracker = require('ssns.completion.usage_tracker')
  local Cache = require('ssns.cache')

  -- Get active database
  local active_db = Cache.get_active_database()
  if not active_db then
    vim.notify("No active database connection", vim.log.levels.WARN)
    return
  end

  local server = active_db.parent
  local connection_key = server.connection_string

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
function Ssns.export_usage_weights(filepath)
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
function Ssns.import_usage_weights(filepath)
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
function Ssns.toggle_usage_tracking()
  local Config = require('ssns.config')
  local config = Config.get()

  -- Toggle setting
  config.completion.track_usage = not config.completion.track_usage

  -- Notify user
  local status = config.completion.track_usage and "enabled" or "disabled"
  vim.notify(string.format("Usage tracking %s", status), vim.log.levels.INFO)
end

---Toggle semantic highlighting for current buffer
function Ssns.toggle_semantic_highlighting()
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

---Run all IntelliSense tests
function Ssns.run_all_tests()
  local Testing = require('ssns.testing')
  Testing.run_all_tests()
end

---Run a specific test by number
---@param test_number number The test number to run
function Ssns.run_test(test_number)
  local Testing = require('ssns.testing')
  Testing.run_test(test_number)
end

---Run tests in a specific category folder
---@param category string Category folder name
function Ssns.run_category_tests(category)
  local Testing = require('ssns.testing')
  local results = Testing.runner.run_category_tests(category)

  if #results == 0 then
    vim.notify(string.format("No tests found in category: %s", category), vim.log.levels.WARN)
    return
  end

  -- Display results
  Testing.reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/ssns/test_results_%s.md", category)
  local success = Testing.reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end
end

---Run tests filtered by completion type
---@param completion_type string The completion type (table, column, schema, etc.)
function Ssns.run_tests_by_type(completion_type)
  local Testing = require('ssns.testing')
  Testing.run_tests_by_type(completion_type)
end

---Open the test results markdown file
function Ssns.view_test_results()
  local results_path = vim.fn.stdpath("data") .. "/ssns/test_results.md"

  -- Check if file exists
  if vim.fn.filereadable(results_path) ~= 1 then
    vim.notify("Test results file not found. Run :SSNSRunTests first.", vim.log.levels.WARN)
    return
  end

  -- Open file in a new buffer
  vim.cmd("edit " .. vim.fn.fnameescape(results_path))
  vim.notify("Opened test results: " .. results_path, vim.log.levels.INFO)
end

return Ssns
