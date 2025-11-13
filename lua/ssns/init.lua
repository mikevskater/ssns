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

  -- Register commands
  Ssns._register_commands()
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
function Ssns.open()
  local Buffer = require('ssns.ui.buffer')
  local Tree = require('ssns.ui.tree')

  Buffer.open()
  Tree.render()
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

return Ssns
