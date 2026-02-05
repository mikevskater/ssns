---@class UiConnectionPicker
---Connection picker for attaching SQL files to SSNS connections
local UiConnectionPicker = {}

local UiFloat = require('nvim-float.window')
local ContentBuilder = require('nvim-float.content')
local UiQuery = require('nvim-ssns.ui.core.query')
local Cache = require('nvim-ssns.cache')
local Connections = require('nvim-ssns.connections')
local Config = require('nvim-ssns.config')
local QueryParser = require('nvim-ssns.query_parser')

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
    local SemanticHighlighter = require('nvim-ssns.highlighting.semantic')
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
      -- Start connecting spinner in lualine
      UiQuery.start_connecting(bufnr, connection.server_name, connection.db_name)

      server:connect_and_load_async({
        on_complete = function(success, connect_err)
          if not success then
            UiQuery.stop_connecting(bufnr, nil, nil)
            vim.notify(string.format("SSNS: Failed to connect: %s", connect_err or "Unknown error"), vim.log.levels.ERROR)
            return
          end

          -- Stop spinner and find database
          UiQuery.stop_connecting(bufnr, server, nil)
          find_database_and_finish(server)
        end,
      })
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

-- ============================================================================
-- Server Picker (Simple - database from context)
-- ============================================================================

---Render server list using ContentBuilder with element tracking
---@param servers table[] Server list
---@param current_key string? Current connection key
---@return ContentBuilder cb
local function build_server_list_content(servers, current_key)
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

  -- Server list with element tracking
  for i, srv in ipairs(servers) do
    local status_icon = srv.connected and "● " or "○ "
    local status_style = srv.connected and "success" or "muted"

    cb:spans({
      { text = "  ", style = "text" },
      { text = status_icon, style = status_style },
      {
        text = srv.server_name,
        style = "server",
        track = {
          name = "server_" .. i,
          type = "server",
          data = { server = srv, index = i },
          row_based = true,
        },
      },
    })
  end

  cb:blank()

  return cb
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

  -- Build content
  local cb = build_server_list_content(servers, current_key)

  -- Create picker window
  local picker = UiFloat.create({
    title = " Attach Server ",
    footer = " <CR> Attach | j/k Navigate | ? Controls ",
    width = 50,
    height = math.min(#servers + 10, 25),
    center = true,
    cursorline = true,
    filetype = "nvim-float",
    content_builder = cb,
    controls = {
      {
        header = "Server Picker",
        keys = {
          { key = "j/k", desc = "Navigate up/down" },
          { key = "Enter", desc = "Attach server" },
          { key = "Esc", desc = "Cancel" },
        },
      },
    },
  })

  if not picker then return end

  -- Store data for use in keymaps
  picker._picker_data = {
    servers = servers,
    target_bufnr = bufnr,
  }

  -- Position cursor on first server (line after header)
  -- Header: blank, legend, context hint, blank, current, separator, blank = 7 lines
  vim.schedule(function()
    if picker:is_valid() then
      picker:set_cursor(8, 0)
    end
  end)

  -- Setup Enter keymap to select server at cursor
  vim.keymap.set('n', '<CR>', function()
    local element = picker:get_element_at_cursor()
    if not element or element.type ~= "server" then
      return -- Not on a server element
    end

    local connection = element.data.server
    local target_bufnr = picker._picker_data.target_bufnr

    picker:close()

    -- Attach the connection
    attach_connection_to_buffer(target_bufnr, connection)
  end, { buffer = picker.bufnr, nowait = true })
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

-- ============================================================================
-- Hierarchical Picker (Server → Database)
-- ============================================================================

---Build content for hierarchical picker (server or database mode)
---@param mode string "server" or "database"
---@param servers table[]? Server list (for server mode)
---@param databases table[]? Database list (for database mode)
---@param server_info table? Selected server info (for database mode)
---@return ContentBuilder cb
local function build_hierarchical_content(mode, servers, databases, server_info)
  local cb = ContentBuilder.new()

  if mode == "server" then
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

    -- Server list with element tracking
    for i, srv in ipairs(servers or {}) do
      local status_icon = srv.connected and "● " or "○ "
      local status_style = srv.connected and "success" or "muted"

      cb:spans({
        { text = "  ", style = "text" },
        { text = status_icon, style = status_style },
        {
          text = srv.server_name,
          style = "server",
          track = {
            name = "server_" .. i,
            type = "server",
            data = { server = srv, index = i },
            row_based = true,
          },
        },
      })
    end

    cb:blank()
  else
    -- Database list header
    cb:blank()
    cb:spans({
      { text = " Server: ", style = "label" },
      { text = server_info.server_name, style = "server" },
    })
    cb:styled(" ─────────────────────────────", "muted")
    cb:blank()

    -- Database list with element tracking
    for i, db in ipairs(databases or {}) do
      cb:spans({
        { text = "  ", style = "text" },
        {
          text = db.db_name,
          style = "sql_database",
          track = {
            name = "database_" .. i,
            type = "database",
            data = { database = db, index = i },
            row_based = true,
          },
        },
      })
    end

    cb:blank()
  end

  return cb
end

---Internal function to show hierarchical picker after servers are loaded
---@param bufnr number Buffer number
---@param servers table[] Server list
local function show_hierarchical_with_servers(bufnr, servers)
  if #servers == 0 then
    vim.notify("SSNS: No servers found. Use :SSNSAddServer to add one.", vim.log.levels.WARN)
    return
  end

  -- Build initial content (server mode)
  local cb = build_hierarchical_content("server", servers, nil, nil)

  -- Create picker window
  local picker = UiFloat.create({
    title = " Select Server ",
    footer = " <CR> Next | j/k Navigate | ? Controls ",
    width = 50,
    height = math.min(#servers + 8, 25),
    center = true,
    cursorline = true,
    filetype = "nvim-float",
    content_builder = cb,
    controls = {
      {
        header = "Connection Picker",
        keys = {
          { key = "j/k", desc = "Navigate up/down" },
          { key = "Enter", desc = "Next step / Attach" },
          { key = "Backspace", desc = "Go back (in database view)" },
          { key = "Esc", desc = "Cancel" },
        },
      },
    },
  })

  if not picker then return end

  -- Store state for use in keymaps
  picker._picker_data = {
    mode = "server",
    servers = servers,
    target_bufnr = bufnr,
    server_info = nil,
    databases = nil,
  }

  -- Position cursor on first server (line 5 after header)
  vim.schedule(function()
    if picker:is_valid() then
      picker:set_cursor(5, 0)
    end
  end)

  -- Helper to switch to database mode
  local function switch_to_database_mode(server_info, databases_list)
    picker._picker_data.mode = "database"
    picker._picker_data.server_info = server_info
    picker._picker_data.databases = databases_list

    -- Rebuild content
    local new_cb = build_hierarchical_content("database", nil, databases_list, server_info)
    picker._content_builder = new_cb

    -- Re-render
    picker:render()

    -- Update title/footer
    picker:update_title(string.format(" %s - Select Database ", server_info.server_name))
    picker:update_footer(" <CR> Attach | <BS> Back | j/k Navigate ")

    -- Position cursor on first database
    vim.schedule(function()
      if picker:is_valid() then
        picker:set_cursor(5, 0)
      end
    end)
  end

  -- Setup Enter keymap
  vim.keymap.set('n', '<CR>', function()
    local data = picker._picker_data

    if data.mode == "server" then
      -- Server mode - select server and show databases
      local element = picker:get_element_at_cursor()
      if not element or element.type ~= "server" then
        return
      end

      local server_info = element.data.server
      local server = server_info.server

      -- Helper to show databases
      local function show_databases()
        local databases_list = server.databases or {}
        if #databases_list == 0 then
          vim.notify("SSNS: No databases found on server", vim.log.levels.WARN)
          return
        end
        switch_to_database_mode(server_info, databases_list)
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
      -- Database mode - select database and attach
      local element = picker:get_element_at_cursor()
      if not element or element.type ~= "database" then
        return
      end

      local selected_db = element.data.database
      local target_bufnr = data.target_bufnr

      picker:close()

      local connection = {
        server_name = data.server_info.server_name,
        db_name = selected_db.db_name,
        server = data.server_info.server,
        database = selected_db,
        connected = true,
      }

      attach_connection_to_buffer(target_bufnr, connection)
    end
  end, { buffer = picker.bufnr, nowait = true })

  -- Setup Backspace keymap to go back to server mode
  vim.keymap.set('n', '<BS>', function()
    local data = picker._picker_data
    if data.mode ~= "database" then
      return -- Already in server mode
    end

    -- Switch back to server mode
    data.mode = "server"
    data.server_info = nil
    data.databases = nil

    -- Rebuild content
    local new_cb = build_hierarchical_content("server", data.servers, nil, nil)
    picker._content_builder = new_cb

    -- Re-render
    picker:render()

    -- Update title/footer
    picker:update_title(" Select Server ")
    picker:update_footer(" <CR> Next | j/k Navigate | ? Controls ")

    -- Position cursor on first server
    vim.schedule(function()
      if picker:is_valid() then
        picker:set_cursor(5, 0)
      end
    end)
  end, { buffer = picker.bufnr, nowait = true })
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

-- ============================================================================
-- Database Picker (for current server)
-- ============================================================================

---Build content for database picker
---@param databases table[] Database list
---@param server table Server object
---@param current_db table? Currently selected database
---@return ContentBuilder cb
local function build_database_picker_content(databases, server, current_db)
  local cb = ContentBuilder.new()

  cb:blank()
  cb:spans({
    { text = " Server: ", style = "label" },
    { text = server.name, style = "server" },
  })
  cb:styled(" ─────────────────────────────────────", "muted")
  cb:blank()

  for i, db in ipairs(databases) do
    local is_current = current_db and db.db_name == current_db.db_name

    local spans = {
      { text = "  ", style = "text" },
      {
        text = db.db_name,
        style = "sql_database",
        track = {
          name = "database_" .. i,
          type = "database",
          data = { database = db, index = i },
          row_based = true,
        },
      },
    }

    if is_current then
      table.insert(spans, { text = " ●", style = "success" })
    end

    cb:spans(spans)
  end

  cb:blank()

  return cb
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

    -- Find current database index for initial cursor position
    local initial_line = 5
    if current_db then
      for i, db in ipairs(databases) do
        if db.db_name == current_db.db_name then
          initial_line = 4 + i
          break
        end
      end
    end

    -- Build content
    local cb = build_database_picker_content(databases, server, current_db)

    -- Create picker window
    local picker = UiFloat.create({
      title = string.format(" %s - Select Database ", server.name),
      footer = " <CR> Switch | j/k Navigate | ? Controls ",
      width = 45,
      height = math.min(#databases + 8, 25),
      center = true,
      cursorline = true,
      filetype = "nvim-float",
      content_builder = cb,
      controls = {
        {
          header = "Database Picker",
          keys = {
            { key = "j/k", desc = "Navigate up/down" },
            { key = "Enter", desc = "Switch database" },
            { key = "Esc", desc = "Cancel" },
          },
        },
      },
    })

    if not picker then return end

    -- Store data
    picker._picker_data = {
      databases = databases,
      server = server,
      target_bufnr = bufnr,
    }

    -- Position cursor on current database
    vim.schedule(function()
      if picker:is_valid() then
        picker:set_cursor(initial_line, 0)
      end
    end)

    -- Setup Enter keymap
    vim.keymap.set('n', '<CR>', function()
      local element = picker:get_element_at_cursor()
      if not element or element.type ~= "database" then
        return
      end

      local selected_db = element.data.database
      local target_bufnr = picker._picker_data.target_bufnr
      local srv = picker._picker_data.server

      picker:close()

      -- Update buffer connection
      UiQuery.query_buffers[target_bufnr] = {
        server = srv,
        database = selected_db,
        last_database = selected_db.db_name,
      }

      -- Update buffer variable
      local db_key = string.format("%s:%s", srv.name, selected_db.db_name)
      vim.api.nvim_buf_set_var(target_bufnr, 'ssns_db_key', db_key)

      -- Setup semantic highlighting
      local SemanticHighlighter = require('nvim-ssns.highlighting.semantic')
      SemanticHighlighter.setup_buffer(target_bufnr)

      vim.notify(string.format("SSNS: Switched to database %s", selected_db.db_name), vim.log.levels.INFO)

      -- Refresh statusline
      vim.cmd('redrawstatus')
      pcall(function()
        require('lualine').refresh()
      end)
    end, { buffer = picker.bufnr, nowait = true })
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
    -- Start connecting spinner in lualine
    UiQuery.start_connecting(bufnr, server.name, current_db and current_db.db_name or nil)

    server:connect_and_load_async({
      on_complete = function(success, err)
        UiQuery.stop_connecting(bufnr, success and server or nil, current_db)

        if not success then
          vim.notify(string.format("SSNS: Failed to connect: %s", err or "Unknown error"), vim.log.levels.ERROR)
          return
        end
        show_picker()
      end,
    })
    return
  end

  load_and_show()
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

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
