---@class AddServerUI
---Floating UI for adding and managing server connections
local AddServerUI = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local Connections = require('ssns.connections')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')

-- Current state
local current_float = nil
local current_screen = "list"  -- "list" or "new"
local selected_index = 1
local connections_list = {}

-- Database type options
local DB_TYPES = {
  { id = "sqlserver", label = "SQL Server", icon = "" },
  { id = "mysql", label = "MySQL", icon = "" },
  { id = "postgres", label = "PostgreSQL", icon = "" },
  { id = "sqlite", label = "SQLite", icon = "" },
}

-- Authentication type options
local AUTH_TYPES = {
  sqlserver = {
    { id = "windows", label = "Windows Authentication" },
    { id = "sql", label = "SQL Server Authentication" },
  },
  mysql = {
    { id = "sql", label = "Username/Password" },
    { id = "none", label = "No Authentication" },
  },
  postgres = {
    { id = "sql", label = "Username/Password" },
    { id = "none", label = "No Authentication" },
  },
  sqlite = {
    { id = "none", label = "No Authentication" },
  },
}

-- Default ports
local DEFAULT_PORTS = {
  sqlserver = 1433,
  mysql = 3306,
  postgres = 5432,
  sqlite = nil,
}

-- Placeholder hints for server path by type
local PATH_HINTS = {
  sqlserver = ".\\SQLEXPRESS  or  localhost\\INSTANCE  or  192.168.1.100",
  mysql = "localhost  or  192.168.1.100",
  postgres = "localhost  or  192.168.1.100",
  sqlite = "C:\\path\\to\\database.db  or  /path/to/database.db",
}

---Parse a server path string to extract host and instance
---@param server_path string User-entered string like "SERVER\INSTANCE" or "localhost"
---@return string host The server hostname
---@return string? instance The instance name (SQL Server only) or nil
local function parse_server_path(server_path)
  if not server_path or server_path == "" then
    return "", nil
  end

  -- Check for backslash (SQL Server instance notation)
  local host, instance = server_path:match("^([^\\]+)\\(.+)$")
  if host and instance then
    return host, instance
  end

  return server_path, nil
end

---Format a connection's server path for display
---@param connection ConnectionData The connection data
---@return string server_path Display string for UI
local function format_server_path(connection)
  if not connection.server then
    return ""
  end

  local path = connection.server.host or ""

  if connection.server.instance then
    path = path .. "\\" .. connection.server.instance
  end

  return path
end

---Build a ConnectionData object from form state
---@param form_state table Form state from UI inputs
---@return ConnectionData connection Complete connection data object
local function build_connection_data(form_state)
  local host, instance = parse_server_path(form_state.server_path)

  -- For SQLite, host is the file path
  if form_state.db_type == "sqlite" then
    host = form_state.server_path
    instance = nil
  end

  local connection = {
    name = form_state.name,
    type = form_state.db_type,
    server = {
      host = host,
      instance = instance,
      port = form_state.port,
      database = form_state.database,
    },
    auth = {
      type = form_state.auth_type,
      username = form_state.username,
      password = form_state.password,
    },
    options = {},
    favorite = form_state.favorite,
    auto_connect = form_state.auto_connect,
  }

  -- Add ODBC driver for SQL Server Windows auth
  if form_state.db_type == "sqlserver" and form_state.auth_type == "windows" then
    local odbc_driver = form_state.odbc_driver
    if not odbc_driver or odbc_driver == "" then
      -- Auto-detect best ODBC driver
      local ConnectionString = require('ssns.connection_string')
      odbc_driver = ConnectionString.get_best_odbc_driver()
    end
    connection.options.odbc_driver = odbc_driver
    connection.options.trust_server_certificate = true
  end

  return connection
end

---Create form state from existing connection data
---@param connection ConnectionData Existing connection to edit
---@return table form_state Form state with all fields
local function form_state_from_connection(connection)
  local server_path = format_server_path(connection)

  return {
    name = connection.name or "",
    server_path = server_path,
    db_type = connection.type or "sqlserver",
    database = connection.server and connection.server.database or "",
    port = connection.server and connection.server.port,
    auth_type = connection.auth and connection.auth.type or "windows",
    username = connection.auth and connection.auth.username or "",
    password = connection.auth and connection.auth.password or "",
    odbc_driver = connection.options and connection.options.odbc_driver or "",
    favorite = connection.favorite or false,
    auto_connect = connection.auto_connect or false,
  }
end

---Get type label and icon for a db_type
---@param db_type string
---@return string label, string icon
local function get_type_info(db_type)
  for _, t in ipairs(DB_TYPES) do
    if t.id == db_type then
      return t.label, t.icon
    end
  end
  return "Unknown", ""
end

---Get auth type label
---@param db_type string
---@param auth_type string
---@return string label
local function get_auth_label(db_type, auth_type)
  local auth_opts = AUTH_TYPES[db_type] or {}
  for _, a in ipairs(auth_opts) do
    if a.id == auth_type then
      return a.label
    end
  end
  return auth_type
end

---Close the current floating window
function AddServerUI.close()
  if current_float then
    pcall(function() current_float:close() end)
  end
  current_float = nil
  current_screen = "list"
  selected_index = 1
end

---Open the Add Server UI
function AddServerUI.open()
  AddServerUI.close()

  connections_list = Connections.load()

  if #connections_list == 0 then
    AddServerUI.show_new_connection_form()
  else
    AddServerUI.show_connection_list()
  end
end

---Check if a connection is already in the tree
---@param name string Connection name
---@return boolean
local function is_in_tree(name)
  return Cache.server_exists(name)
end

---Show the list of saved connections
function AddServerUI.show_connection_list()
  -- Close any existing float first to prevent window stacking
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "list"
  connections_list = Connections.load()

  -- Build styled content
  local cb = ContentBuilder.new()

  if #connections_list == 0 then
    cb:blank()
    cb:styled("  No saved connections", "muted")
    cb:blank()
    cb:spans({
      { text = "  Press ", style = "muted" },
      { text = "n", style = "key" },
      { text = " to create a new connection", style = "muted" },
    })
    cb:blank()
  else
    cb:blank()

    for i, conn in ipairs(connections_list) do
      local in_tree = is_in_tree(conn.name)
      local _, icon = get_type_info(conn.type or "sqlserver")

      -- Selection indicator
      local prefix = i == selected_index and "  " or "   "

      -- Build spans for this connection line
      local spans = {}

      if i == selected_index then
        -- Selected item - use server style for icon, name
        table.insert(spans, { text = prefix, style = "selected" })
        table.insert(spans, { text = icon .. " ", style = "server" })
        table.insert(spans, { text = conn.name, style = "server" })
      else
        -- Unselected - dimmed icon
        table.insert(spans, { text = prefix, style = "text" })
        table.insert(spans, { text = icon .. " ", style = "muted" })
        table.insert(spans, { text = conn.name, style = "text" })
      end

      -- Add status indicators
      if conn.favorite or conn.auto_connect then
        table.insert(spans, { text = " ★", style = "warning" })
      end
      if conn.auto_connect then
        table.insert(spans, { text = "⚡", style = "warning" })
      end
      if in_tree then
        table.insert(spans, { text = " [active]", style = "success" })
      end

      cb:spans(spans)
    end

    cb:blank()
  end

  -- Help section
  cb:styled("  ───────────────────────────────────────────", "muted")
  cb:blank()
  cb:spans({
    { text = "  a Enter", style = "key" },
    { text = "   Add to tree       ", style = "text" },
    { text = "n", style = "key" },
    { text = "   New", style = "text" },
  })
  cb:spans({
    { text = "  e", style = "key" },
    { text = "         Edit              ", style = "text" },
    { text = "d", style = "key" },
    { text = "   Delete", style = "text" },
  })
  cb:spans({
    { text = "  f *", style = "key" },
    { text = "       Toggle favorite   ", style = "text" },
    { text = "q", style = "key" },
    { text = "   Close", style = "text" },
  })
  cb:spans({
    { text = "  j k", style = "key" },
    { text = "       Navigate", style = "text" },
  })
  cb:blank()

  -- Get keymaps from config
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  -- Build keymaps table dynamically
  local keymaps = {}
  keymaps[common.close or "q"] = function() AddServerUI.close() end
  keymaps[common.cancel or "<Esc>"] = function() AddServerUI.close() end
  keymaps[common.nav_down or "j"] = function() AddServerUI.navigate(1) end
  keymaps[common.nav_up or "k"] = function() AddServerUI.navigate(-1) end
  keymaps[common.nav_down_alt or "<Down>"] = function() AddServerUI.navigate(1) end
  keymaps[common.nav_up_alt or "<Up>"] = function() AddServerUI.navigate(-1) end
  keymaps[km.add or "a"] = function() AddServerUI.add_selected_to_tree() end
  keymaps[common.confirm or "<CR>"] = function() AddServerUI.add_selected_to_tree() end
  keymaps[km.new or "n"] = function() AddServerUI.show_new_connection_form() end
  keymaps[km.delete or "d"] = function() AddServerUI.delete_selected() end
  keymaps[km.edit_connection or "e"] = function() AddServerUI.edit_selected() end
  keymaps[km.toggle_favorite or "f"] = function() AddServerUI.toggle_favorite_selected() end
  keymaps[km.toggle_favorite_alt or "*"] = function() AddServerUI.toggle_favorite_selected() end

  -- Create floating window with styled content
  current_float = UiFloat.create_styled(cb, {
    title = " Server Connections ",
    title_pos = "center",
    footer = " ★ favorite  ⚡ auto-connect ",
    footer_pos = "center",
    border = "rounded",
    min_width = 48,
    min_height = 10,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
  })

  -- Position cursor on selected item
  if current_float and current_float:is_valid() and #connections_list > 0 then
    current_float:set_cursor(1 + selected_index, 0)
  end
end

---Navigate the connection list
---@param direction number 1 for down, -1 for up
function AddServerUI.navigate(direction)
  if #connections_list == 0 then
    return
  end

  selected_index = selected_index + direction

  -- Wrap around
  if selected_index < 1 then
    selected_index = #connections_list
  elseif selected_index > #connections_list then
    selected_index = 1
  end

  -- Refresh the list display
  AddServerUI.show_connection_list()

  -- Position cursor on selected item
  if current_float and current_float:is_valid() then
    current_float:set_cursor(1 + selected_index, 0)
  end
end

---Add the selected connection to the tree
function AddServerUI.add_selected_to_tree()
  if #connections_list == 0 then
    vim.notify("No connections to add", vim.log.levels.WARN)
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  -- Check if already in tree
  if is_in_tree(conn.name) then
    vim.notify(string.format("'%s' is already in tree", conn.name), vim.log.levels.INFO)
    return
  end

  -- Add server to cache
  local server, err = Cache.add_server_from_connection(conn)

  if server then
    vim.notify(string.format("Added '%s' to tree", conn.name), vim.log.levels.INFO)

    -- Close the UI
    AddServerUI.close()

    -- Refresh tree
    local UiTree = require('ssns.ui.core.tree')
    UiTree.render()
  else
    vim.notify(string.format("Failed to add '%s': %s", conn.name, err or "Unknown error"), vim.log.levels.ERROR)
  end
end

---Delete the selected connection
function AddServerUI.delete_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  -- Confirm deletion
  local confirm = vim.fn.confirm(
    string.format("Delete connection '%s'?", conn.name),
    "&Yes\n&No",
    2
  )

  if confirm ~= 1 then
    return
  end

  -- Remove from file
  if Connections.remove(conn.name) then
    vim.notify(string.format("Deleted '%s'", conn.name), vim.log.levels.INFO)

    -- Adjust selected index if needed
    if selected_index > #connections_list - 1 then
      selected_index = math.max(1, #connections_list - 1)
    end

    -- Refresh list
    AddServerUI.show_connection_list()
  end
end

---Edit the selected connection
function AddServerUI.edit_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  AddServerUI.show_new_connection_form(conn)
end

---Toggle favorite status for the selected connection
function AddServerUI.toggle_favorite_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  local success, new_state = Connections.toggle_favorite(conn.name)

  if success then
    local status = new_state and "added to" or "removed from"
    vim.notify(string.format("'%s' %s favorites", conn.name, status), vim.log.levels.INFO)

    -- Refresh list
    AddServerUI.show_connection_list()

    -- Restore cursor position
    if current_float and current_float:is_valid() then
      current_float:set_cursor(1 + selected_index, 0)
    end
  end
end

---Show the new connection form
---@param edit_connection ConnectionData? Existing connection to edit
function AddServerUI.show_new_connection_form(edit_connection)
  -- Close any existing float first to prevent window stacking
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "new"
  local is_edit = edit_connection ~= nil

  -- Form state
  local form_state
  if edit_connection then
    form_state = form_state_from_connection(edit_connection)
  else
    form_state = {
      name = "",
      server_path = "",
      db_type = "sqlserver",
      database = "",
      port = nil,
      auth_type = "windows",
      username = "",
      password = "",
      odbc_driver = "",
      favorite = false,
      auto_connect = false,
    }
  end

  AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
end

---Show form with current state (refreshes content while keeping keymaps functional)
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  -- Close existing float and recreate to ensure keymaps are fresh
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "new"
  local is_edit = edit_connection ~= nil

  -- Get type info
  local type_label, type_icon = get_type_info(form_state.db_type)
  local path_hint = PATH_HINTS[form_state.db_type] or ""
  local auth_label = get_auth_label(form_state.db_type, form_state.auth_type)
  local is_sqlite = form_state.db_type == "sqlite"
  local needs_auth_creds = form_state.auth_type == "sql"

  -- Build styled content
  local cb = ContentBuilder.new()

  -- Server Type section
  cb:blank()
  cb:styled("  SERVER TYPE", "section")
  cb:spans({
    { text = "  " .. type_icon .. " ", style = "server" },
    { text = type_label, style = "value" },
  })
  cb:spans({
    { text = "  Press ", style = "muted" },
    { text = "t", style = "key" },
    { text = " to change", style = "muted" },
  })
  cb:blank()

  -- Connection Name section
  cb:styled("  CONNECTION NAME", "section")
  local name_display = form_state.name ~= "" and form_state.name or "(not set)"
  if form_state.name ~= "" then
    cb:styled("  " .. name_display, "value")
  else
    cb:styled("  " .. name_display, "muted")
  end
  cb:spans({
    { text = "  Press ", style = "muted" },
    { text = "n", style = "key" },
    { text = " to set", style = "muted" },
  })
  cb:blank()

  -- Server Path section
  local path_title = is_sqlite and "  DATABASE FILE" or "  SERVER"
  cb:styled(path_title, "section")
  local path_display = form_state.server_path ~= "" and form_state.server_path or "(not set)"
  if form_state.server_path ~= "" then
    cb:styled("  " .. path_display, "value")
  else
    cb:styled("  " .. path_display, "muted")
  end
  cb:spans({
    { text = "  Press ", style = "muted" },
    { text = "p", style = "key" },
    { text = " to set", style = "muted" },
  })
  cb:styled("  " .. path_hint, "hint")
  cb:blank()

  -- Database section (not for SQLite)
  if not is_sqlite then
    cb:styled("  DATABASE (optional)", "section")
    local db_display = form_state.database ~= "" and form_state.database or "(default)"
    if form_state.database ~= "" then
      cb:styled("  " .. db_display, "database")
    else
      cb:styled("  " .. db_display, "muted")
    end
    cb:spans({
      { text = "  Press ", style = "muted" },
      { text = "D", style = "key" },
      { text = " to set", style = "muted" },
    })
    cb:blank()
  end

  -- Authentication section (not for SQLite)
  if not is_sqlite then
    cb:styled("  AUTHENTICATION", "section")
    cb:styled("  " .. auth_label, "value")
    cb:spans({
      { text = "  Press ", style = "muted" },
      { text = "A", style = "key" },
      { text = " to change", style = "muted" },
    })

    -- Show username/password fields for SQL auth
    if needs_auth_creds then
      cb:blank()

      local user_display = form_state.username ~= "" and form_state.username or "(not set)"
      cb:spans({
        { text = "  Username: ", style = "label" },
        { text = user_display, style = form_state.username ~= "" and "value" or "muted" },
      })

      local pass_display = form_state.password ~= "" and string.rep("*", #form_state.password) or "(not set)"
      cb:spans({
        { text = "  Password: ", style = "label" },
        { text = pass_display, style = form_state.password ~= "" and "value" or "muted" },
      })

      cb:spans({
        { text = "  Press ", style = "muted" },
        { text = "u", style = "key" },
        { text = "/", style = "muted" },
        { text = "P", style = "key" },
        { text = " to set credentials", style = "muted" },
      })
    end

    cb:blank()
  end

  -- Options section
  cb:styled("  OPTIONS", "section")

  local fav_checkbox = form_state.favorite and "[x]" or "[ ]"
  local auto_checkbox = form_state.auto_connect and "[x]" or "[ ]"

  cb:spans({
    { text = "  " .. fav_checkbox .. " ", style = form_state.favorite and "success" or "muted" },
    { text = "★", style = "warning" },
    { text = " Favorite          Show in tree on startup", style = "muted" },
  })

  cb:spans({
    { text = "  " .. auto_checkbox .. " ", style = form_state.auto_connect and "success" or "muted" },
    { text = "⚡", style = "warning" },
    { text = " Auto-connect      Connect automatically", style = "muted" },
  })

  cb:spans({
    { text = "  Press ", style = "muted" },
    { text = "f", style = "key" },
    { text = " or ", style = "muted" },
    { text = "a", style = "key" },
    { text = " to toggle", style = "muted" },
  })
  cb:blank()

  -- Actions section
  cb:styled("  ───────────────────────────────────────────", "muted")
  cb:blank()
  cb:spans({
    { text = "  s", style = "key" },
    { text = "   Save connection       ", style = "text" },
    { text = "T", style = "key" },
    { text = "   Test connection", style = "text" },
  })
  cb:spans({
    { text = "  b", style = "key" },
    { text = "   Back to list          ", style = "text" },
    { text = "q", style = "key" },
    { text = "   Close", style = "text" },
  })
  cb:blank()

  local title = is_edit and " Edit Connection " or " New Connection "

  -- Get keymaps from config
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  -- Build keymaps table dynamically
  local keymaps = {}
  keymaps[common.close or "q"] = function() AddServerUI.close() end
  keymaps[common.cancel or "<Esc>"] = function()
    if #connections_list > 0 then
      AddServerUI.show_connection_list()
    else
      AddServerUI.close()
    end
  end
  keymaps[km.back or "b"] = function()
    if #connections_list > 0 then
      AddServerUI.show_connection_list()
    else
      AddServerUI.close()
    end
  end
  keymaps[km.db_type or "t"] = function()
    AddServerUI.prompt_db_type(form_state, edit_connection)
  end
  keymaps[km.set_name or "n"] = function()
    AddServerUI.prompt_name(form_state, edit_connection)
  end
  keymaps[km.set_path or "p"] = function()
    AddServerUI.prompt_server_path(form_state, edit_connection)
  end
  keymaps["D"] = function()
    AddServerUI.prompt_database(form_state, edit_connection)
  end
  keymaps["A"] = function()
    AddServerUI.prompt_auth_type(form_state, edit_connection)
  end
  keymaps["u"] = function()
    AddServerUI.prompt_username(form_state, edit_connection)
  end
  keymaps["P"] = function()
    AddServerUI.prompt_password(form_state, edit_connection)
  end
  keymaps[km.toggle_favorite or "f"] = function()
    form_state.favorite = not form_state.favorite
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.toggle_auto_connect or "a"] = function()
    form_state.auto_connect = not form_state.auto_connect
    -- Auto-connect implies favorite
    if form_state.auto_connect then
      form_state.favorite = true
    end
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.save or "s"] = function()
    AddServerUI.save_connection(form_state, edit_connection)
  end
  keymaps[km.test or "T"] = function()
    AddServerUI.test_connection(form_state)
  end

  -- Create fresh float with styled content
  current_float = UiFloat.create_styled(cb, {
    title = title,
    title_pos = "center",
    border = "rounded",
    min_width = 52,
    min_height = 20,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
  })
end

---Prompt for database type selection
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_db_type(form_state, edit_connection)
  -- Build selection items
  local items = {}
  for _, t in ipairs(DB_TYPES) do
    table.insert(items, string.format("%s %s", t.icon, t.label))
  end

  vim.ui.select(items, {
    prompt = "Select Database Type:",
  }, function(choice, idx)
    if choice and idx then
      local new_type = DB_TYPES[idx].id
      form_state.db_type = new_type

      -- Reset auth to default for new type
      local auth_opts = AUTH_TYPES[new_type]
      if auth_opts and #auth_opts > 0 then
        form_state.auth_type = auth_opts[1].id
      end

      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for connection name
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_name(form_state, edit_connection)
  vim.ui.input({
    prompt = "Connection Name: ",
    default = form_state.name,
  }, function(input)
    if input and input ~= "" then
      form_state.name = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for server path
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_server_path(form_state, edit_connection)
  local hint = PATH_HINTS[form_state.db_type] or ""
  local prompt = form_state.db_type == "sqlite" and "Database File" or "Server"
  if hint ~= "" then
    prompt = prompt .. " (e.g. " .. hint:match("^([^%s]+)") .. ")"
  end
  prompt = prompt .. ": "

  vim.ui.input({
    prompt = prompt,
    default = form_state.server_path,
  }, function(input)
    if input then
      form_state.server_path = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for database name
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_database(form_state, edit_connection)
  vim.ui.input({
    prompt = "Database (leave empty for default): ",
    default = form_state.database,
  }, function(input)
    if input ~= nil then
      form_state.database = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for auth type selection
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_auth_type(form_state, edit_connection)
  local auth_opts = AUTH_TYPES[form_state.db_type] or {}

  if #auth_opts == 0 then
    vim.notify("No authentication options for this database type", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, a in ipairs(auth_opts) do
    table.insert(items, a.label)
  end

  vim.ui.select(items, {
    prompt = "Select Authentication Type:",
  }, function(choice, idx)
    if choice and idx then
      form_state.auth_type = auth_opts[idx].id
      -- Clear credentials when switching to non-SQL auth
      if form_state.auth_type ~= "sql" then
        form_state.username = ""
        form_state.password = ""
      end
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for username
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_username(form_state, edit_connection)
  vim.ui.input({
    prompt = "Username: ",
    default = form_state.username,
  }, function(input)
    if input ~= nil then
      form_state.username = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for password
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.prompt_password(form_state, edit_connection)
  vim.ui.input({
    prompt = "Password: ",
    default = form_state.password,
  }, function(input)
    if input ~= nil then
      form_state.password = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Save the connection
---@param form_state table Current form values
---@param edit_connection ConnectionData? Original connection being edited
function AddServerUI.save_connection(form_state, edit_connection)
  -- Validate
  if form_state.name == "" then
    vim.notify("Connection name is required", vim.log.levels.ERROR)
    return
  end

  if form_state.server_path == "" then
    vim.notify("Server path is required", vim.log.levels.ERROR)
    return
  end

  -- Build structured connection data
  local connection = build_connection_data(form_state)

  local success
  if edit_connection then
    -- Update existing
    success = Connections.update(edit_connection.name, connection)
    if success then
      vim.notify(string.format("Updated '%s'", connection.name), vim.log.levels.INFO)
    end
  else
    -- Add new
    success = Connections.add(connection)
    if success then
      vim.notify(string.format("Saved '%s'", connection.name), vim.log.levels.INFO)
    end
  end

  if success then
    -- If favorite is set, automatically add to tree (if not already there)
    if connection.favorite or connection.auto_connect then
      if not Cache.server_exists(connection.name) then
        local server, err = Cache.add_server_from_connection(connection)
        if server then
          -- If auto_connect, also connect the server
          if connection.auto_connect then
            server:connect()
          end
          -- Refresh tree to show the new server
          local UiTree = require('ssns.ui.core.tree')
          UiTree.render()
        end
      end
    end

    -- Reload list and show it
    connections_list = Connections.load()
    AddServerUI.show_connection_list()
  end
end

---Test the connection
---@param form_state table Current form values
function AddServerUI.test_connection(form_state)
  if form_state.server_path == "" then
    vim.notify("Server path is required", vim.log.levels.ERROR)
    return
  end

  vim.notify("Testing connection...", vim.log.levels.INFO)

  -- Build structured connection data
  local connection = build_connection_data(form_state)

  -- Create a temporary server to test the connection
  local Factory = require('ssns.factory')
  local test_name = "_test_" .. os.time()

  local server, err = Factory.create_server(test_name, connection)

  if not server then
    vim.notify(string.format("Connection failed: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Try to connect
  local connect_ok, connect_err = pcall(function()
    return server:connect()
  end)

  if connect_ok and server:is_connected() then
    vim.notify("Connection successful!", vim.log.levels.INFO)
    -- Disconnect the test server
    pcall(function() server:disconnect() end)
  else
    vim.notify(string.format("Connection failed: %s", connect_err or "Could not connect"), vim.log.levels.ERROR)
  end
end

return AddServerUI
