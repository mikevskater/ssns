---@class UiConnectionPicker
---Connection picker for attaching SQL files to SSNS connections
local UiConnectionPicker = {}

local UiFloatInteractive = require('ssns.ui.base.float_interactive')
local UiQuery = require('ssns.ui.core.query')
local Cache = require('ssns.cache')
local Connections = require('ssns.connections')
local Config = require('ssns.config')
local KeymapManager = require('ssns.keymap_manager')
---@return table[] servers List of server entries
local function get_all_servers()
  local servers = {}
  local seen = {}

  -- Add currently connected servers first
  for _, server in ipairs(Cache.servers) do
    if not seen[server.name] then
      seen[server.name] = true
      table.insert(servers, {
        display = server:is_connected() and string.format("● %s", server.name) or string.format("○ %s", server.name),
        server_name = server.name,
        server = server,
        connected = server:is_connected(),
      })
    end
  end

  -- Add saved connections from file
  local saved_connections = Connections.load()
  for _, conn in ipairs(saved_connections) do
    if not seen[conn.name] then
      seen[conn.name] = true
      table.insert(servers, {
        display = string.format("○ %s", conn.name),
        server_name = conn.name,
        connection_config = conn,
        connected = false,
      })
    end
  end

  -- Add connections from config
  local config_connections = Config.get_connections()
  for name, cfg in pairs(config_connections) do
    if not seen[name] then
      seen[name] = true
      table.insert(servers, {
        display = string.format("○ %s", name),
        server_name = name,
        connection_config = cfg,
        connected = false,
      })
    end
  end

  return servers
end

---Attach a connection to a buffer
---@param bufnr number Buffer number
---@param connection table Connection info (server-only or server+database)
---@param callback function? Optional callback after attachment
local function attach_connection_to_buffer(bufnr, connection, callback)
  local server = connection.server

  -- If not connected, we need to connect first
  if not connection.connected then
    -- Try to find existing server in cache
    server = Cache.find_server(connection.server_name)

    if not server then
      -- Create and connect new server
      local err
      server, err = Cache.find_or_create_server(connection.server_name, connection.connection_config)

      if not server then
        vim.notify(string.format("SSNS: Failed to create server: %s", err or "Unknown error"), vim.log.levels.ERROR)
        return
      end
    end

    -- Connect if not already connected
    if not server:is_connected() then
      vim.notify(string.format("SSNS: Connecting to %s...", connection.server_name), vim.log.levels.INFO)
      local success, connect_err = server:connect()
      if not success then
        vim.notify(string.format("SSNS: Failed to connect: %s", connect_err or "Unknown error"), vim.log.levels.ERROR)
        return
      end
    end

    connection.server = server
    connection.connected = true
  end

  -- If database is specified, find it; otherwise use nil (context parsing will determine)
  local database = connection.database
  if connection.db_name and not database then
    for _, db in ipairs(server.databases or {}) do
      if db.db_name == connection.db_name then
        database = db
        break
      end
    end
  end

  -- Set the ssns_db_key buffer variable (server only, or server:database if specified)
  local db_key
  if database then
    db_key = string.format("%s:%s", connection.server_name, database.db_name)
  else
    -- Server-only key - context parsing will determine database from USE statements
    db_key = connection.server_name
  end
  vim.api.nvim_buf_set_var(bufnr, 'ssns_db_key', db_key)

  -- Track in query_buffers
  UiQuery.query_buffers[bufnr] = {
    server = server,
    database = database,  -- May be nil for server-only attachment
    last_database = database and database.db_name or nil,
  }

  -- Setup query keymaps for this buffer
  UiQuery.setup_query_keymaps(bufnr)

  -- Setup semantic highlighting
  local SemanticHighlighter = require('ssns.highlighting.semantic')
  SemanticHighlighter.setup_buffer(bufnr)

  if database then
    vim.notify(string.format("SSNS: Buffer attached to %s → %s", connection.server_name, database.db_name), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Buffer attached to %s (database from context)", connection.server_name), vim.log.levels.INFO)
  end

  -- Refresh statusline to show connection info
  vim.cmd('redrawstatus')

  -- Also try to refresh lualine if available
  pcall(function()
    require('lualine').refresh()
  end)

  if callback then
    callback()
  end
end

---Show the server picker for the current buffer (database determined by context)
---@param bufnr number? Buffer number (defaults to current)
function UiConnectionPicker.show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer is a SQL file
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if filetype ~= 'sql' then
    vim.notify("SSNS: Current buffer is not a SQL file", vim.log.levels.WARN)
    return
  end

  local servers = get_all_servers()

  if #servers == 0 then
    vim.notify("SSNS: No saved connections found. Use :SSNSAddServer to add one.", vim.log.levels.WARN)
    return
  end

  -- Get current connection
  local current_key = nil
  pcall(function()
    current_key = vim.api.nvim_buf_get_var(bufnr, 'ssns_db_key')
  end)

  -- Create picker using UiFloatInteractive
  local state = UiFloatInteractive.create({
    title = " Attach Server ",
    footer = " <CR> Attach | <Esc> Cancel | j/k Navigate ",
    width = 50,
    height = math.min(#servers + 10, 25),
    header_lines = 7,  -- Number of lines before selectable items
    item_count = #servers,  -- Number of selectable items
    initial_data = {
      servers = servers,
      target_bufnr = bufnr,
      current_key = current_key,
    },
    on_render = function(st)
      local lines = {}
      local ns_id = vim.api.nvim_create_namespace("ssns_connection_picker")

      -- Header
      table.insert(lines, "")
      table.insert(lines, " ● = Connected   ○ = Saved")
      table.insert(lines, " Database from context (USE statements)")
      table.insert(lines, "")

      -- Current connection info
      if st.data.current_key then
        table.insert(lines, string.format(" Current: %s", st.data.current_key))
      else
        table.insert(lines, " Current: (none)")
      end

      table.insert(lines, " ─────────────────────────────────────────")
      table.insert(lines, "")

      -- Server list
      for i, srv in ipairs(st.data.servers) do
        local line = UiFloatInteractive.add_indicator(srv.display, i == st.selected_idx)
        table.insert(lines, line)
      end

      table.insert(lines, "")

      -- Apply highlights
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(st.bufnr) then
          vim.api.nvim_buf_clear_namespace(st.bufnr, ns_id, 0, -1)
          for line_idx, line in ipairs(lines) do
            if line:match("─────") or line:match("● =") or line:match("Database from") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Comment", line_idx - 1, 0, -1)
            elseif line:match("Current:") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Title", line_idx - 1, 0, 9)
            elseif line:match("▶") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "SsnsFloatSelected", line_idx - 1, 0, -1)
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Special", line_idx - 1, 1, 4)
            end
          end
        end
      end)

      return lines
    end,
    on_select = function(st)
      if st.selected_idx < 1 or st.selected_idx > #st.data.servers then
        return
      end

      local connection = st.data.servers[st.selected_idx]
      local target_bufnr = st.data.target_bufnr

      UiFloatInteractive.close(st)

      -- Attach the connection
      attach_connection_to_buffer(target_bufnr, connection)
    end,
  })

  if state then
    -- Window options
    vim.api.nvim_set_option_value('cursorline', true, { win = state.winid })
    vim.api.nvim_set_option_value('number', false, { win = state.winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.winid })
  end
end

---Show hierarchical server→database picker
---@param bufnr number? Buffer number (defaults to current)
function UiConnectionPicker.show_hierarchical(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer is a SQL file
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if filetype ~= 'sql' then
    vim.notify("SSNS: Current buffer is not a SQL file", vim.log.levels.WARN)
    return
  end

  local servers = get_all_servers()

  if #servers == 0 then
    vim.notify("SSNS: No servers found. Use :SSNSAddServer to add one.", vim.log.levels.WARN)
    return
  end

  -- Create picker using UiFloatInteractive
  local state = UiFloatInteractive.create({
    title = " Select Server ",
    footer = " <CR> Next | <Esc> Cancel | j/k Navigate ",
    width = 50,
    height = math.min(#servers + 8, 25),
    header_lines = 4,  -- Empty, legend, separator, empty
    item_count = #servers,
    initial_data = {
      mode = "server",
      servers = servers,
      target_bufnr = bufnr,
    },
    on_render = function(st)
      local lines = {}
      local ns_id = vim.api.nvim_create_namespace("ssns_hierarchical_picker")

      if st.data.mode == "server" then
        -- Server list
        table.insert(lines, "")
        table.insert(lines, " ● = Connected   ○ = Saved")
        table.insert(lines, " ─────────────────────────────")
        table.insert(lines, "")

        for i, srv in ipairs(st.data.servers) do
          local line = UiFloatInteractive.add_indicator(srv.display, i == st.selected_idx)
          table.insert(lines, line)
        end

        table.insert(lines, "")
      else
        -- Database list
        table.insert(lines, "")
        table.insert(lines, string.format(" Server: %s", st.data.server_info.server_name))
        table.insert(lines, " ─────────────────────────────")
        table.insert(lines, "")

        for i, db in ipairs(st.data.databases) do
          local line = UiFloatInteractive.add_indicator(db.db_name, i == st.selected_idx)
          table.insert(lines, line)
        end

        table.insert(lines, "")
      end

      -- Apply highlights
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(st.bufnr) then
          vim.api.nvim_buf_clear_namespace(st.bufnr, ns_id, 0, -1)
          for line_idx, line in ipairs(lines) do
            if line:match("─────") or line:match("● =") or line:match("Server:") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Comment", line_idx - 1, 0, -1)
            elseif line:match("▶") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "SsnsFloatSelected", line_idx - 1, 0, -1)
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Special", line_idx - 1, 1, 4)
            end
          end
        end
      end)

      return lines
    end,
    on_select = function(st)
      if st.data.mode == "server" then
        -- Server selected - show databases
        if st.selected_idx < 1 or st.selected_idx > #st.data.servers then
          return
        end

        local server_info = st.data.servers[st.selected_idx]
        local server = server_info.server

        -- Connect if needed
        if not server_info.connected then
          if not server then
            local err
            server, err = Cache.find_or_create_server(server_info.server_name, server_info.connection_config)
            if not server then
              vim.notify(string.format("SSNS: Failed to create server: %s", err or "Unknown error"), vim.log.levels.ERROR)
              return
            end
          end

          if not server:is_connected() then
            vim.notify(string.format("SSNS: Connecting to %s...", server_info.server_name), vim.log.levels.INFO)
            local success, connect_err = server:connect()
            if not success then
              vim.notify(string.format("SSNS: Failed to connect: %s", connect_err or "Unknown error"), vim.log.levels.ERROR)
              return
            end
          end

          server_info.server = server
          server_info.connected = true
        end

        -- Load databases if not yet loaded
        if not server.databases or #server.databases == 0 then
          vim.notify(string.format("SSNS: Loading databases from %s...", server_info.server_name), vim.log.levels.INFO)
          local load_success = server:load()
          if not load_success then
            vim.notify(string.format("SSNS: Failed to load databases: %s", server.error_message or "Unknown error"), vim.log.levels.ERROR)
            return
          end
        end

        local databases = server.databases or {}
        if #databases == 0 then
          vim.notify("SSNS: No databases found on server", vim.log.levels.WARN)
          return
        end

        -- Switch to database mode
        st.data.mode = "database"
        st.data.databases = databases
        st.data.server_info = server_info
        st.selected_idx = 1
        st.config.item_count = #databases  -- Update item count for database list
        st.config.header_lines = 4  -- Empty, server name, separator, empty

        -- Update UI
        UiFloatInteractive.update_title(st, string.format(" %s - Select Database ", server_info.server_name))
        UiFloatInteractive.update_footer(st, " <CR> Attach | <BS> Back | <Esc> Cancel | j/k Navigate ")
        UiFloatInteractive.render(st)
      else
        -- Database selected - attach
        if st.selected_idx < 1 or st.selected_idx > #st.data.databases then
          return
        end

        local selected_db = st.data.databases[st.selected_idx]
        local target_bufnr = st.data.target_bufnr

        UiFloatInteractive.close(st)

        local connection = {
          server_name = st.data.server_info.server_name,
          db_name = selected_db.db_name,
          server = st.data.server_info.server,
          database = selected_db,
          connected = true,
        }

        attach_connection_to_buffer(target_bufnr, connection)
      end
    end,
    custom_keymaps = {
      ["<BS>"] = function(st)
        -- Go back from database to server list
        if st.data.mode == "database" then
          st.data.mode = "server"
          st.selected_idx = 1
          st.config.item_count = #st.data.servers  -- Restore server item count
          st.config.header_lines = 4  -- Empty, legend, separator, empty
          UiFloatInteractive.update_title(st, " Select Server ")
          UiFloatInteractive.update_footer(st, " <CR> Next | <Esc> Cancel | j/k Navigate ")
          UiFloatInteractive.render(st)
        end
      end,
    },
  })

  if state then
    vim.api.nvim_set_option_value('cursorline', true, { win = state.winid })
    vim.api.nvim_set_option_value('number', false, { win = state.winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.winid })
  end
end

---Get current connection info for a buffer
---@param bufnr number? Buffer number (defaults to current)
---@return string? db_key The ssns_db_key or nil
function UiConnectionPicker.get_current_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, db_key = pcall(vim.api.nvim_buf_get_var, bufnr, 'ssns_db_key')
  return ok and db_key or nil
end

---Detach connection from buffer
---@param bufnr number? Buffer number (defaults to current)
function UiConnectionPicker.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Remove buffer variable
  pcall(vim.api.nvim_buf_del_var, bufnr, 'ssns_db_key')

  -- Remove from query_buffers tracking
  UiQuery.query_buffers[bufnr] = nil

  vim.notify("SSNS: Connection detached from buffer", vim.log.levels.INFO)
end

---Show database picker for current server connection
---@param bufnr number? Buffer number (defaults to current)
function UiConnectionPicker.show_database_picker(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer is a SQL file
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if filetype ~= 'sql' then
    vim.notify("SSNS: Current buffer is not a SQL file", vim.log.levels.WARN)
    return
  end

  -- Get current connection
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info or not buffer_info.server then
    vim.notify("SSNS: No server attached to this buffer. Use :SSNSAttach first.", vim.log.levels.WARN)
    return
  end

  local server = buffer_info.server

  -- Make sure server is connected
  if not server:is_connected() then
    vim.notify(string.format("SSNS: Connecting to %s...", server.name), vim.log.levels.INFO)
    local success, err = server:connect()
    if not success then
      vim.notify(string.format("SSNS: Failed to connect: %s", err or "Unknown error"), vim.log.levels.ERROR)
      return
    end
  end

  -- Load databases if not yet loaded
  if not server.databases or #server.databases == 0 then
    vim.notify(string.format("SSNS: Loading databases from %s...", server.name), vim.log.levels.INFO)
    local load_success = server:load()
    if not load_success then
      vim.notify(string.format("SSNS: Failed to load databases: %s", server.error_message or "Unknown error"), vim.log.levels.ERROR)
      return
    end
  end

  -- Get databases
  local databases = server.databases or {}
  if #databases == 0 then
    vim.notify("SSNS: No databases found on server", vim.log.levels.WARN)
    return
  end

  -- Find current database index
  local current_db = buffer_info.database
  local initial_idx = 1
  if current_db then
    for i, db in ipairs(databases) do
      if db.db_name == current_db.db_name then
        initial_idx = i
        break
      end
    end
  end

  -- Create picker using UiFloatInteractive
  local state = UiFloatInteractive.create({
    title = string.format(" %s - Select Database ", server.name),
    footer = " <CR> Switch | <Esc> Cancel | j/k Navigate ",
    width = 45,
    height = math.min(#databases + 8, 25),
    header_lines = 4,  -- Empty, server name, separator, empty
    item_count = #databases,
    initial_data = {
      databases = databases,
      server = server,
      target_bufnr = bufnr,
      current_db = current_db,
      initial_idx = initial_idx,
    },
    on_render = function(st)
      local lines = {}
      local ns_id = vim.api.nvim_create_namespace("ssns_db_picker")

      table.insert(lines, "")
      table.insert(lines, string.format(" Server: %s", server.name))
      table.insert(lines, " ─────────────────────────────────────")
      table.insert(lines, "")

      for i, db in ipairs(st.data.databases) do
        local is_current = st.data.current_db and db.db_name == st.data.current_db.db_name
        local suffix = is_current and " ●" or ""
        local line = UiFloatInteractive.add_indicator(db.db_name .. suffix, i == st.selected_idx)
        table.insert(lines, line)
      end

      table.insert(lines, "")

      -- Apply highlights
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(st.bufnr) then
          vim.api.nvim_buf_clear_namespace(st.bufnr, ns_id, 0, -1)
          for line_idx, line in ipairs(lines) do
            if line:match("─────") or line:match("Server:") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Comment", line_idx - 1, 0, -1)
            elseif line:match("▶") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "SsnsFloatSelected", line_idx - 1, 0, -1)
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "Special", line_idx - 1, 1, 4)
            end
            if line:match("●") then
              vim.api.nvim_buf_add_highlight(st.bufnr, ns_id, "DiagnosticOk", line_idx - 1, #line - 2, -1)
            end
          end
        end
      end)

      return lines
    end,
    on_select = function(st)
      if st.selected_idx < 1 or st.selected_idx > #st.data.databases then
        return
      end

      local selected_db = st.data.databases[st.selected_idx]
      local target_bufnr = st.data.target_bufnr

      UiFloatInteractive.close(st)

      local connection = {
        server_name = st.data.server.name,
        db_name = selected_db.db_name,
        server = st.data.server,
        database = selected_db,
        connected = true,
      }

      attach_connection_to_buffer(target_bufnr, connection)
    end,
  })

  if state then
    -- Set initial selection to current database
    state.selected_idx = initial_idx
    UiFloatInteractive.render(state)

    vim.api.nvim_set_option_value('cursorline', true, { win = state.winid })
    vim.api.nvim_set_option_value('number', false, { win = state.winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.winid })
  end
end

return UiConnectionPicker
