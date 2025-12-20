---@class Ssns
---SQL Server NeoVim Studio
---A pure Lua Neovim plugin for database management with SSMS-style UI
local Ssns = {}

---Plugin version
Ssns.version = "0.8.0-dev"

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

  -- Initialize lualine colors cache asynchronously (for non-blocking statusline)
  local LualineColors = require('ssns.lualine_colors')
  LualineColors.init_async()

  -- Load servers from configuration
  local Cache = require('ssns.cache')
  local Connections = require('ssns.connections')

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

  -- Load favorite connections asynchronously (shown in tree but not connected)
  -- This prevents blocking during startup for file I/O
  Connections.get_favorites_async(function(favorites, load_err)
    if load_err then
      vim.schedule(function()
        vim.notify(
          string.format("SSNS: Failed to load saved connections: %s", load_err),
          vim.log.levels.WARN
        )
      end)
      return
    end

    local favorite_count = 0
    local auto_connect_servers = {}

    -- First pass: add all favorite servers to cache (fast, no I/O)
    for _, conn in ipairs(favorites) do
      -- Skip if already loaded from config
      if not Cache.server_exists(conn.name) then
        local server, err = Cache.add_server_from_connection(conn)
        if server then
          favorite_count = favorite_count + 1
          -- Collect servers needing auto-connect
          if conn.auto_connect then
            table.insert(auto_connect_servers, { server = server, name = conn.name })
          end
        else
          vim.schedule(function()
            vim.notify(
              string.format("SSNS: Failed to load favorite '%s': %s", conn.name, err or "Unknown error"),
              vim.log.levels.WARN
            )
          end)
        end
      end
    end

    -- Report initial load (servers added to tree, not yet connected)
    vim.schedule(function()
      local total_servers = #servers + favorite_count
      if total_servers > 0 then
        local msg = string.format("SSNS: Loaded %d connection(s)", total_servers)
        if #auto_connect_servers > 0 then
          msg = msg .. string.format(" (connecting to %d...)", #auto_connect_servers)
        end
        vim.notify(msg, vim.log.levels.INFO)
      end
    end)

    -- Second pass: auto-connect servers asynchronously
    -- Each connection is done in sequence to avoid overwhelming the backend
    if #auto_connect_servers > 0 then
      local connected_count = 0
      local failed_count = 0

      local function connect_next(index)
        if index > #auto_connect_servers then
          -- All connections attempted, report final status
          vim.schedule(function()
            if connected_count > 0 then
              vim.notify(
                string.format("SSNS: Auto-connected to %d server(s)", connected_count),
                vim.log.levels.INFO
              )
            end
          end)
          return
        end

        local item = auto_connect_servers[index]
        local server = item.server
        local name = item.name

        -- Use true async RPC to avoid blocking
        server:connect_async(function(success, connect_err)
          if success then
            connected_count = connected_count + 1
          else
            failed_count = failed_count + 1
            vim.notify(
              string.format("SSNS: Failed to auto-connect '%s': %s", name, connect_err or "Unknown error"),
              vim.log.levels.WARN
            )
          end

          -- Continue to next server
          connect_next(index + 1)
        end)
      end

      -- Start connecting servers
      connect_next(1)
    end
  end)

  -- Setup UI highlights
  local Highlights = require('ssns.ui.core.highlights')
  Highlights.setup()
  Highlights.setup_filetype()

  -- Setup semantic highlighting for SQL query buffers
  local SemanticHighlighter = require('ssns.highlighting.semantic')
  SemanticHighlighter.setup()

  -- Initialize query history (async to avoid blocking startup)
  local QueryHistory = require('ssns.query_history')
  local config = Config.get()
  QueryHistory.max_buffers = config.query_history.max_buffers
  QueryHistory.max_entries_per_buffer = config.query_history.max_entries_per_buffer
  QueryHistory.auto_persist = config.query_history.auto_persist
  QueryHistory.persist_file = config.query_history.persist_file
  QueryHistory.exclude_patterns = config.query_history.exclude_patterns
  if config.query_history.enabled then
    QueryHistory.init_async(function(success, err)
      if not success and err then
        vim.schedule(function()
          vim.notify("SSNS: Failed to load query history: " .. err, vim.log.levels.WARN)
        end)
      end
    end)
  end

  -- Pre-load user snippets asynchronously for faster completion
  local Snippets = require('ssns.completion.data.snippets')
  Snippets.init_async()

  -- Pre-load lualine colors cache asynchronously
  local LualineColors = require('ssns.lualine_colors')
  LualineColors.init_async()

  -- Register commands via commands module
  local Commands = require('ssns.commands')
  Commands.register()

  -- Setup keymaps for SQL buffers
  Ssns._setup_sql_filetype_keymaps()
end

---Setup keymaps for SQL filetype buffers
function Ssns._setup_sql_filetype_keymaps()
  local Config = require('ssns.config')

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "sql",
    callback = function(args)
      local bufnr = args.buf
      local KeymapManager = require('ssns.keymap_manager')
      local keymaps = Config.get_keymaps()
      local query_keymaps = keymaps.query or {}

      -- Build list of keymaps to set
      local sql_keymaps = {
        -- Show controls popup
        {
          mode = "n",
          lhs = "?",
          rhs = function()
            local UiQuery = require('ssns.ui.core.query')
            UiQuery.show_query_controls()
          end,
          desc = "SSNS: Show controls",
        },
        -- Expand asterisk keymap
        {
          mode = "n",
          lhs = "<Leader>ce",
          rhs = function()
            local ExpandAsterisk = require('ssns.features.expand_asterisk')
            ExpandAsterisk.expand_asterisk_at_cursor()
          end,
          desc = "SSNS: Expand asterisk (Columns Expand)",
        },
        -- Attach connection keymap
        {
          mode = "n",
          lhs = query_keymaps.attach_connection or "<A-s>",
          rhs = function()
            local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
            ConnectionPicker.show(bufnr)
          end,
          desc = "SSNS: Attach buffer to connection",
        },
        -- Change connection keymap (hierarchical picker)
        {
          mode = "n",
          lhs = query_keymaps.change_connection or "<A-S>",
          rhs = function()
            local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
            ConnectionPicker.show_hierarchical(bufnr)
          end,
          desc = "SSNS: Change connection (pick server then database)",
        },
      }

      -- Add optional keymaps if configured
      if keymaps.go_to then
        table.insert(sql_keymaps, {
          mode = "n",
          lhs = keymaps.go_to,
          rhs = function()
            local GoTo = require('ssns.features.go_to')
            GoTo.go_to_object_at_cursor()
          end,
          desc = "SSNS: Go to object in tree",
        })
      end

      if keymaps.view_definition then
        table.insert(sql_keymaps, {
          mode = "n",
          lhs = keymaps.view_definition,
          rhs = function()
            local ViewDefinition = require('ssns.features.view_definition')
            ViewDefinition.view_definition_at_cursor()
          end,
          desc = "SSNS: View object definition",
        })
      end

      if keymaps.view_metadata then
        table.insert(sql_keymaps, {
          mode = "n",
          lhs = keymaps.view_metadata,
          rhs = function()
            local ViewMetadata = require('ssns.features.view_metadata')
            ViewMetadata.view_metadata_at_cursor()
          end,
          desc = "SSNS: View object metadata",
        })
      end

      -- Set all keymaps using KeymapManager (saves conflicts for restoration)
      KeymapManager.set_multiple(bufnr, sql_keymaps, true)
      KeymapManager.mark_group_active(bufnr, "sql_filetype")

      -- Enable semantic highlighting for SQL files
      local sh_config = Config.get_semantic_highlighting()
      if sh_config.enabled then
        local SemanticHighlighter = require('ssns.highlighting.semantic')
        SemanticHighlighter.setup_buffer(bufnr)
      end

      -- Setup SQL formatter keymaps and format-on-save
      local formatter_config = Config.get_formatter()
      if formatter_config.enabled then
        local FormatterCommands = require('ssns.formatter.commands')
        FormatterCommands.setup_buffer(bufnr)
      end
    end,
  })
end

-- UI Functions (delegate to ui modules)

---Toggle the tree UI
function Ssns.toggle()
  local Buffer = require('ssns.ui.core.buffer')
  local Tree = require('ssns.ui.core.tree')
  Buffer.toggle()
  if Buffer.is_open() then
    Tree.render()
  end
end

---Open the tree UI
---@param mode_override string? Optional mode override: "float" or "docked"
function Ssns.open(mode_override)
  local Buffer = require('ssns.ui.core.buffer')
  local Tree = require('ssns.ui.core.tree')
  Buffer.open(mode_override)
  Tree.render()
end

---Open the tree UI in floating window mode
function Ssns.open_float()
  Ssns.open("float")
end

---Open the tree UI in docked/split mode
function Ssns.open_docked()
  Ssns.open("docked")
end

---Close the tree UI
function Ssns.close()
  local Buffer = require('ssns.ui.core.buffer')
  Buffer.close()
end

-- Connection Functions (delegate to api/connections)

---Refresh all servers
function Ssns.refresh_all()
  require('ssns.api.connections').refresh_all()
end

---Connect to a saved connection
---@param connection_name string
function Ssns.connect(connection_name)
  require('ssns.api.connections').connect(connection_name)
end

---Open a new query buffer
function Ssns.new_query()
  local Query = require('ssns.ui.core.query')
  local Cache = require('ssns.cache')
  local servers = Cache.get_all_servers()

  if #servers == 0 then
    vim.notify("SSNS: No servers configured", vim.log.levels.WARN)
    return
  end

  if #servers == 1 then
    Query.create_query_buffer(servers[1], nil, nil)
    return
  end

  local server_names = {}
  for _, server in ipairs(servers) do
    table.insert(server_names, server.name)
  end

  vim.ui.select(server_names, { prompt = "Select server:" }, function(choice, idx)
    if choice then
      Query.create_query_buffer(servers[idx], nil, nil)
    end
  end)
end

---Attach current buffer to a connection (flat picker)
function Ssns.attach()
  require('ssns.api.connections').attach()
end

---Attach current buffer to a connection (hierarchical picker)
function Ssns.attach_pick()
  require('ssns.api.connections').attach_pick()
end

---Detach connection from current buffer
function Ssns.detach()
  require('ssns.api.connections').detach()
end

---Get current connection info for buffer
---@param bufnr number? Buffer number (defaults to current)
---@return string? db_key The connection key or nil
function Ssns.get_connection(bufnr)
  return require('ssns.api.connections').get_connection(bufnr)
end

---Change database for current server connection
function Ssns.change_database()
  require('ssns.api.connections').change_database()
end

-- Diagnostics Functions (delegate to api/diagnostics)

---Show cache statistics
function Ssns.show_stats()
  require('ssns.api.diagnostics').show_stats()
end

---Debug cache contents
function Ssns.debug()
  require('ssns.api.diagnostics').debug()
end

---Show query history
function Ssns.show_history()
  require('ssns.api.connections').show_history()
end

---Show database object search UI
function Ssns.show_object_search()
  require('ssns.api.connections').show_object_search()
end

---Clear query history
function Ssns.clear_history()
  require('ssns.api.connections').clear_history()
end

---Export query history
---@param filepath string? Optional file path
function Ssns.export_history(filepath)
  require('ssns.api.connections').export_history(filepath)
end

---Show completion performance statistics
function Ssns.show_completion_stats()
  require('ssns.api.diagnostics').show_completion_stats()
end

---Reset completion performance statistics
function Ssns.reset_completion_stats()
  require('ssns.api.diagnostics').reset_completion_stats()
end

---Show usage-based completion statistics
function Ssns.show_usage_stats()
  require('ssns.api.diagnostics').show_usage_stats()
end

---Clear all usage weights
function Ssns.clear_usage_weights()
  require('ssns.api.diagnostics').clear_usage_weights()
end

---Clear usage weights for current connection only
function Ssns.clear_usage_weights_current()
  require('ssns.api.diagnostics').clear_usage_weights_current()
end

---Export usage weights to a JSON file
---@param filepath string? Optional file path
function Ssns.export_usage_weights(filepath)
  require('ssns.api.diagnostics').export_usage_weights(filepath)
end

---Import usage weights from a JSON file
---@param filepath string? Optional file path
function Ssns.import_usage_weights(filepath)
  require('ssns.api.diagnostics').import_usage_weights(filepath)
end

---Toggle usage tracking on/off
function Ssns.toggle_usage_tracking()
  require('ssns.api.diagnostics').toggle_usage_tracking()
end

---Toggle semantic highlighting for current buffer
function Ssns.toggle_semantic_highlighting()
  require('ssns.api.diagnostics').toggle_semantic_highlighting()
end

-- Testing Functions

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

  Testing.reporter.display_results(results)
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

  if vim.fn.filereadable(results_path) ~= 1 then
    vim.notify("Test results file not found. Run :SSNSRunTests first.", vim.log.levels.WARN)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(results_path))
  vim.notify("Opened test results: " .. results_path, vim.log.levels.INFO)
end

-- Advanced API accessors

---Get current version
---@return string version
function Ssns.get_version()
  return Ssns.version
end

---Get cache instance
---@return Cache
function Ssns.get_cache()
  return require('ssns.cache')
end

---Get factory instance
---@return Factory
function Ssns.get_factory()
  return require('ssns.factory')
end

---Get config instance
---@return Config
function Ssns.get_config()
  return require('ssns.config')
end

return Ssns
