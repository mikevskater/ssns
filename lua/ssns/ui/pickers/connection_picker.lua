---@class UiConnectionPicker
---Connection picker for attaching SQL files to SSNS connections
local UiConnectionPicker = {}

local UiFloatInteractive = require('ssns.ui.base.float_interactive')
local ContentBuilder = require('ssns.ui.core.content_builder')
local UiFloat = require('ssns.ui.core.float')
local UiQuery = require('ssns.ui.core.query')
local Cache = require('ssns.cache')
local Connections = require('ssns.connections')
local Config = require('ssns.config')
local QueryParser = require('ssns.query_parser')

---Show controls popup for server picker
local function show_server_picker_controls()
  local controls = {
    {
      header = "Server Picker",
      keys = {
        { key = "j/k", desc = "Navigate up/down" },
        { key = "Enter", desc = "Select server / Attach" },
        { key = "Esc", desc = "Cancel" },
      },
    },
  }
  UiFloat._show_controls_popup(controls)
end

---Show controls popup for hierarchical picker
local function show_hierarchical_picker_controls()
  local controls = {
    {
      header = "Connection Picker",
      keys = {
        { key = "j/k", desc = "Navigate up/down" },
        { key = "Enter", desc = "Next step / Attach" },
        { key = "Backspace", desc = "Go back (in database view)" },
        { key = "Esc", desc = "Cancel" },
      },
    },
  }
  UiFloat._show_controls_popup(controls)
end

---Show controls popup for database picker
local function show_database_picker_controls()
  local controls = {
    {
      header = "Database Picker",
      keys = {
        { key = "j/k", desc = "Navigate up/down" },
        { key = "Enter", desc = "Switch database" },
        { key = "Esc", desc = "Cancel" },
      },
    },
  }
  UiFloat._show_controls_popup(controls)
end

---Get the default database name for a server type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return string default_db Default database name
local function get_default_database(db_type)
  if db_type == "sqlserver" then
    return "master"
  elseif db_type == "postgres" or db_type == "postgresql" then
    return "postgres"
  elseif db_type == "mysql" then
    return "mysql"
  elseif db_type == "sqlite" then
    return "main"
  else
    return "master"  -- fallback
  end
end

---Parse buffer content to find the last USE statement database
---@param bufnr number Buffer number
---@return string? database Database name from last USE statement, or nil
local function get_database_from_buffer_context(bufnr)
  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  if content == "" then
    return nil
  end

  -- Parse USE statements from the buffer
  local chunks = QueryParser.parse_use_statements(content)

  -- Find the last chunk with a database set (from USE statement)
  local last_database = nil
  for _, chunk in ipairs(chunks) do
    if chunk.database then
      last_database = chunk.database
    end
  end

  return last_database
end

---Get all servers asynchronously (non-blocking)
---@param callback fun(servers: table[]) Callback with server list
local function get_all_servers_async(callback)
  -- Add currently connected servers first (sync - just in-memory)
  local servers = {}
  local seen = {}

  for _, server in ipairs(Cache.servers) do
    if not seen[server.name] then
      seen[server.name] = true
      table.insert(servers, {
        server_name = server.name,
        server = server,
        connected = server:is_connected(),
      })
    end
  end

  -- Load saved connections async
  Connections.load_async(function(saved_connections, _)
    for _, conn in ipairs(saved_connections or {}) do
      if not seen[conn.name] then
        seen[conn.name] = true
        table.insert(servers, {
          server_name = conn.name,
          connection_config = conn,
          connected = false,
        })
      end
    end

    -- Add connections from config (sync - just in-memory)
    local config_connections = Config.get_connections()
    for name, cfg in pairs(config_connections) do
      if not seen[name] then
        seen[name] = true
        table.insert(servers, {
          server_name = name,
          connection_config = cfg,
          connected = false,
        })
      end
    end

    callback(servers)
  end)
end

---Attach a connection to a buffer
---@param bufnr number Buffer number
---@param connection table Connection info (server-only or server+database)
---@param callback function? Optional callback after attachment
local function attach_connection_to_buffer(bufnr, connection, callback)
  -- Helper to complete attachment after server/database are ready
  local function finish_attach(server, database, db_name, database_source)
    -- Set the ssns_db_key buffer variable
    local db_key
    if db_name then
      db_key = string.format("%s:%s", connection.server_name, db_name)
    else
      db_key = connection.server_name
    end
    vim.api.nvim_buf_set_var(bufnr, 'ssns_db_key', db_key)

    -- Track in query_buffers
    UiQuery.query_buffers[bufnr] = {
      server = server,
      database = database,
      last_database = db_name,
    }

    -- Setup query keymaps for this buffer
    UiQuery.setup_query_keymaps(bufnr)

    -- Setup semantic highlighting
    local SemanticHighlighter = require('ssns.highlighting.semantic')
    SemanticHighlighter.setup_buffer(bufnr)

    -- Notify based on how database was determined
    if database_source == "explicit" then
      vim.notify(string.format("SSNS: Buffer attached to %s → %s", connection.server_name, db_name), vim.log.levels.INFO)
    elseif database_source == "context" then
      vim.notify(string.format("SSNS: Buffer attached to %s → %s (from USE statement)", connection.server_name, db_name), vim.log.levels.INFO)
    else
      vim.notify(string.format("SSNS: Buffer attached to %s → %s (default)", connection.server_name, db_name), vim.log.levels.INFO)
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

  -- Helper to find database after server is loaded
  local function find_database_and_finish(server)
    local database = connection.database
    local db_name = connection.db_name
    local database_source = "explicit"

    -- If database is specified in connection, find it
    if db_name and not database then
      for _, db in ipairs(server.databases or {}) do
        if db.db_name == db_name then
          database = db
          break
        end
      end
    end

    -- If no database specified, determine from buffer context or use default
    if not database and not db_name then
      -- First, try to parse USE statements from buffer content
      local context_db = get_database_from_buffer_context(bufnr)

      if context_db then
        db_name = context_db
        database_source = "context"

        -- Find the database object
        for _, db in ipairs(server.databases or {}) do
          if db.db_name:lower() == context_db:lower() then
            database = db
            db_name = db.db_name  -- Use proper casing from server
            break
          end
        end
      end

      -- If still no database, use server type default (master, postgres, etc.)
      if not db_name then
        local db_type = server:get_db_type() or "sqlserver"
        db_name = get_default_database(db_type)
        database_source = "default"

        -- Find the default database object
        for _, db in ipairs(server.databases or {}) do
          if db.db_name:lower() == db_name:lower() then
            database = db
            db_name = db.db_name  -- Use proper casing from server
            break
          end
        end
      end
    end

    finish_attach(server, database, db_name, database_source)
  end

  -- Helper to load databases if needed, then find database
  local function ensure_loaded_and_find_database(server)
    if not server.databases or #server.databases == 0 then
      -- Load databases asynchronously
      server:load_async(function(success, _)
        if success then
          find_database_and_finish(server)
        else
          -- Even if load fails, try to continue with what we have
          find_database_and_finish(server)
        end
      end)
    else
      find_database_and_finish(server)
    end
  end

  -- Helper to connect if needed, then load/find database
  local function connect_and_continue(server)
    connection.server = server
    connection.connected = true

    if not server:is_connected() then
      vim.notify(string.format("SSNS: Connecting to %s...", connection.server_name), vim.log.levels.INFO)
      server:connect_async(function(success, connect_err)
        if not success then
          vim.notify(string.format("SSNS: Failed to connect: %s", connect_err or "Unknown error"), vim.log.levels.ERROR)
          return
        end
        ensure_loaded_and_find_database(server)
      end)
    else
      ensure_loaded_and_find_database(server)
    end
  end

  -- Main entry point
  local server = connection.server

  if not connection.connected then
    -- Try to find existing server in cache
    server = Cache.find_server(connection.server_name)

    if not server then
      -- Create new server
      local err
      server, err = Cache.find_or_create_server(connection.server_name, connection.connection_config)

      if not server then
        vim.notify(string.format("SSNS: Failed to create server: %s", err or "Unknown error"), vim.log.levels.ERROR)
        return
      end
    end

    connect_and_continue(server)
  else
    ensure_loaded_and_find_database(server)
  end
end

---Render server list using ContentBuilder
---@param servers table[] Server list
---@param selected_idx number Selected index
---@param current_key string? Current connection key
---@return string[] lines
---@return table[] highlights
local function render_server_list(servers, selected_idx, current_key)
  local cb = ContentBuilder.new()

  -- Header
  cb:blank()
  cb:spans({
    { text = " ", style = "text" },
    { text = "●", style = "success" },
    { text = " = Connected   ", style = "muted" },
    { text = "○", style = "muted" },
    { text = " = Saved", style = "muted" },
  })
  cb:styled(" Database from context (USE statements)", "muted")
  cb:blank()

  -- Current connection info
  if current_key then
    cb:spans({
      { text = " Current: ", style = "label" },
      { text = current_key, style = "server" },
    })
  else
    cb:spans({
      { text = " Current: ", style = "label" },
      { text = "(none)", style = "muted" },
    })
  end

  cb:styled(" ─────────────────────────────────────────", "muted")
  cb:blank()

  -- Server list
  for i, srv in ipairs(servers) do
    local is_selected = i == selected_idx
    local prefix = is_selected and "▶ " or "  "
    local status_icon = srv.connected and "● " or "○ "
    local status_style = srv.connected and "success" or "muted"

    if is_selected then
      cb:spans({
        { text = prefix, style = "emphasis" },
        { text = status_icon, style = status_style },
        { text = srv.server_name, style = "server" },
      })
    else
      cb:spans({
        { text = prefix, style = "text" },
        { text = status_icon, style = status_style },
        { text = srv.server_name, style = "text" },
      })
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

---Internal function to show picker after servers are loaded
---@param bufnr number Buffer number
---@param servers table[] Server list
local function show_picker_with_servers(bufnr, servers)
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
    footer = " <CR> Attach | j/k Navigate | ? Controls ",
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
      return render_server_list(st.data.servers, st.selected_idx, st.data.current_key)
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
    custom_keymaps = {
      ["?"] = function(_)
        show_server_picker_controls()
      end,
    },
  })

  if state then
    -- Window options
    vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
    vim.api.nvim_set_option_value('number', false, { win = state.winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.winid })
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

  -- Load servers asynchronously to avoid blocking
  get_all_servers_async(function(servers)
    show_picker_with_servers(bufnr, servers)
  end)
end

---Render hierarchical picker content using ContentBuilder
---@param st table State
---@return string[] lines
---@return table[] highlights
local function render_hierarchical(st)
  local cb = ContentBuilder.new()

  if st.data.mode == "server" then
    -- Server list header
    cb:blank()
    cb:spans({
      { text = " ", style = "text" },
      { text = "●", style = "success" },
      { text = " = Connected   ", style = "muted" },
      { text = "○", style = "muted" },
      { text = " = Saved", style = "muted" },
    })
    cb:styled(" ─────────────────────────────", "muted")
    cb:blank()

    -- Server list
    for i, srv in ipairs(st.data.servers) do
      local is_selected = i == st.selected_idx
      local prefix = is_selected and "▶ " or "  "
      local status_icon = srv.connected and "● " or "○ "
      local status_style = srv.connected and "success" or "muted"

      if is_selected then
        cb:spans({
          { text = prefix, style = "emphasis" },
          { text = status_icon, style = status_style },
          { text = srv.server_name, style = "server" },
        })
      else
        cb:spans({
          { text = prefix, style = "text" },
          { text = status_icon, style = status_style },
          { text = srv.server_name, style = "text" },
        })
      end
    end

    cb:blank()
  else
    -- Database list header
    cb:blank()
    cb:spans({
      { text = " Server: ", style = "label" },
      { text = st.data.server_info.server_name, style = "server" },
    })
    cb:styled(" ─────────────────────────────", "muted")
    cb:blank()

    -- Database list
    for i, db in ipairs(st.data.databases) do
      local is_selected = i == st.selected_idx
      local prefix = is_selected and "▶ " or "  "

      if is_selected then
        cb:spans({
          { text = prefix, style = "emphasis" },
          { text = db.db_name, style = "database" },
        })
      else
        cb:spans({
          { text = prefix, style = "text" },
          { text = db.db_name, style = "text" },
        })
      end
    end

    cb:blank()
  end

  return cb:build_lines(), cb:build_highlights()
end

---Internal function to show hierarchical picker after servers are loaded
---@param bufnr number Buffer number
---@param servers table[] Server list
local function show_hierarchical_with_servers(bufnr, servers)
  if #servers == 0 then
    vim.notify("SSNS: No servers found. Use :SSNSAddServer to add one.", vim.log.levels.WARN)
    return
  end

  -- Create picker using UiFloatInteractive
  local state = UiFloatInteractive.create({
    title = " Select Server ",
    footer = " <CR> Next | j/k Navigate | ? Controls ",
    width = 50,
    height = math.min(#servers + 8, 25),
    header_lines = 4,  -- Empty, legend, separator, empty
    item_count = #servers,
    initial_data = {
      mode = "server",
      servers = servers,
      target_bufnr = bufnr,
    },
    on_render = render_hierarchical,
    on_select = function(st)
      if st.data.mode == "server" then
        -- Server selected - show databases
        if st.selected_idx < 1 or st.selected_idx > #st.data.servers then
          return
        end

        local server_info = st.data.servers[st.selected_idx]
        local server = server_info.server

        -- Helper to switch to database mode
        local function show_databases()
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
          UiFloatInteractive.update_footer(st, " <CR> Attach | <BS> Back | j/k Navigate | ? Controls ")
          UiFloatInteractive.render(st)
        end

        -- Helper to load databases then show them
        local function load_and_show()
          if not server.databases or #server.databases == 0 then
            vim.notify(string.format("SSNS: Loading databases from %s...", server_info.server_name), vim.log.levels.INFO)
            server:load_async(function(load_success, _)
              if not load_success then
                vim.notify(string.format("SSNS: Failed to load databases: %s", server.error_message or "Unknown error"), vim.log.levels.ERROR)
                return
              end
              show_databases()
            end)
          else
            show_databases()
          end
        end

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

          server_info.server = server
          server_info.connected = true

          if not server:is_connected() then
            vim.notify(string.format("SSNS: Connecting to %s...", server_info.server_name), vim.log.levels.INFO)
            server:connect_async(function(success, connect_err)
              if not success then
                vim.notify(string.format("SSNS: Failed to connect: %s", connect_err or "Unknown error"), vim.log.levels.ERROR)
                return
              end
              load_and_show()
            end)
            return
          end
        end

        load_and_show()
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
          UiFloatInteractive.update_footer(st, " <CR> Next | j/k Navigate | ? Controls ")
          UiFloatInteractive.render(st)
        end
      end,
      ["?"] = function(_)
        show_hierarchical_picker_controls()
      end,
    },
  })

  if state then
    vim.api.nvim_set_option_value('cursorline', false, { win = state.winid })
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

  -- Load servers asynchronously to avoid blocking
  get_all_servers_async(function(servers)
    show_hierarchical_with_servers(bufnr, servers)
  end)
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

---Render database picker using ContentBuilder
---@param st table State
---@param server table Server object
---@return string[] lines
---@return table[] highlights
local function render_database_picker(st, server)
  local cb = ContentBuilder.new()

  cb:blank()
  cb:spans({
    { text = " Server: ", style = "label" },
    { text = server.name, style = "server" },
  })
  cb:styled(" ─────────────────────────────────────", "muted")
  cb:blank()

  for i, db in ipairs(st.data.databases) do
    local is_selected = i == st.selected_idx
    local is_current = st.data.current_db and db.db_name == st.data.current_db.db_name
    local prefix = is_selected and "▶ " or "  "

    local spans = {
      { text = prefix, style = is_selected and "emphasis" or "text" },
      { text = db.db_name, style = is_selected and "database" or "text" },
    }

    if is_current then
      table.insert(spans, { text = " ●", style = "success" })
    end

    cb:spans(spans)
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
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
  local current_db = buffer_info.database

  -- Helper to show the picker once databases are loaded
  local function show_picker()
    local databases = server.databases or {}
    if #databases == 0 then
      vim.notify("SSNS: No databases found on server", vim.log.levels.WARN)
      return
    end

    -- Find current database index
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
      footer = " <CR> Switch | j/k Navigate | ? Controls ",
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
        return render_database_picker(st, server)
      end,
      on_select = function(st)
        if st.selected_idx < 1 or st.selected_idx > #st.data.databases then
          return
        end

        local selected_db = st.data.databases[st.selected_idx]
        local target_bufnr_inner = st.data.target_bufnr

        UiFloatInteractive.close(st)

        -- Update buffer connection
        UiQuery.query_buffers[target_bufnr_inner] = {
          server = st.data.server,
          database = selected_db,
          last_database = selected_db.db_name,
        }

        -- Update buffer variable
        local db_key = string.format("%s:%s", st.data.server.name, selected_db.db_name)
        vim.api.nvim_buf_set_var(target_bufnr_inner, 'ssns_db_key', db_key)

        -- Setup semantic highlighting
        local SemanticHighlighter = require('ssns.highlighting.semantic')
        SemanticHighlighter.setup_buffer(target_bufnr_inner)

        vim.notify(string.format("SSNS: Switched to database %s", selected_db.db_name), vim.log.levels.INFO)

        -- Refresh statusline
        vim.cmd('redrawstatus')
        pcall(function()
          require('lualine').refresh()
        end)
      end,
      on_back = function(_)
        -- No back action for single-level picker
      end,
    })

    state.selected_idx = initial_idx
    UiFloatInteractive.render(state)
  end

  -- Helper to load databases then show picker
  local function load_and_show()
    if not server.databases or #server.databases == 0 then
      vim.notify(string.format("SSNS: Loading databases from %s...", server.name), vim.log.levels.INFO)
      server:load_async(function(load_success, _)
        if not load_success then
          vim.notify(string.format("SSNS: Failed to load databases: %s", server.error_message or "Unknown error"), vim.log.levels.ERROR)
          return
        end
        show_picker()
      end)
    else
      show_picker()
    end
  end

  -- Make sure server is connected
  if not server:is_connected() then
    vim.notify(string.format("SSNS: Connecting to %s...", server.name), vim.log.levels.INFO)
    server:connect_async(function(success, err)
      if not success then
        vim.notify(string.format("SSNS: Failed to connect: %s", err or "Unknown error"), vim.log.levels.ERROR)
        return
      end
      load_and_show()
    end)
    return
  end

  load_and_show()
end

---Get current connection for a buffer
---@param bufnr number? Buffer number
---@return string? db_key Connection key if attached
function UiConnectionPicker.get_current_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, db_key = pcall(vim.api.nvim_buf_get_var, bufnr, 'ssns_db_key')
  return ok and db_key or nil
end

---Detach connection from buffer
---@param bufnr number? Buffer number
function UiConnectionPicker.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if attached
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info then
    vim.notify("SSNS: No connection attached to this buffer", vim.log.levels.WARN)
    return
  end

  -- Clear buffer variable
  pcall(vim.api.nvim_buf_del_var, bufnr, 'ssns_db_key')

  -- Remove from tracking
  UiQuery.query_buffers[bufnr] = nil

  vim.notify("SSNS: Disconnected from buffer", vim.log.levels.INFO)

  -- Refresh statusline
  vim.cmd('redrawstatus')
  pcall(function()
    require('lualine').refresh()
  end)
end

return UiConnectionPicker
