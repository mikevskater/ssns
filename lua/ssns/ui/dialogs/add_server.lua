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

---Show controls popup for connection list view
function AddServerUI.show_list_controls()
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  local controls = {
    {
      header = "Navigation",
      keys = {
        { key = common.nav_down or "j", desc = "Navigate down" },
        { key = common.nav_up or "k", desc = "Navigate up" },
      },
    },
    {
      header = "Actions",
      keys = {
        { key = km.add or "a", desc = "Add selected to tree" },
        { key = common.confirm or "Enter", desc = "Add selected to tree" },
        { key = km.new or "n", desc = "New connection" },
        { key = km.edit_connection or "e", desc = "Edit connection" },
        { key = km.delete or "d", desc = "Delete connection" },
        { key = km.toggle_favorite or "f/*", desc = "Toggle favorite" },
        { key = common.close or "q/Esc", desc = "Close" },
      },
    },
  }

  UiFloat._show_controls_popup(controls)
end

---Show controls popup for connection form view
function AddServerUI.show_form_controls()
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  local controls = {
    {
      header = "Form Navigation",
      keys = {
        { key = "Tab", desc = "Next field" },
        { key = "S-Tab", desc = "Previous field" },
        { key = "Enter", desc = "Edit field / Select dropdown" },
      },
    },
    {
      header = "Actions",
      keys = {
        { key = km.save or "s", desc = "Save connection" },
        { key = km.test or "T", desc = "Test connection" },
        { key = km.toggle_favorite or "f", desc = "Toggle favorite" },
        { key = km.toggle_auto_connect or "a", desc = "Toggle auto-connect" },
        { key = km.back or "b", desc = "Back to list" },
        { key = common.close or "q", desc = "Close" },
      },
    },
  }

  UiFloat._show_controls_popup(controls)
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
  keymaps["?"] = function() AddServerUI.show_list_controls() end

  -- Create floating window with styled content
  current_float = UiFloat.create_styled(cb, {
    title = " Server Connections ",
    title_pos = "center",
    footer = " ★=favorite  ⚡=auto-connect  ?=Controls ",
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
  local path_hint = PATH_HINTS[form_state.db_type] or ""
  local is_sqlite = form_state.db_type == "sqlite"
  local needs_auth_creds = form_state.auth_type == "sql"
  local default_port = DEFAULT_PORTS[form_state.db_type]

  -- Build styled content with inline inputs
  local cb = ContentBuilder.new()

  -- Server Type dropdown
  cb:blank()
  local db_type_options = {}
  for _, t in ipairs(DB_TYPES) do
    table.insert(db_type_options, { value = t.id, label = t.icon .. " " .. t.label })
  end
  cb:dropdown("db_type", {
    label = "  DATABASE TYPE",
    options = db_type_options,
    value = form_state.db_type,
    width = 22,
  })
  cb:blank()

  -- Connection Name (inline input)
  cb:labeled_input("name", "     CONNECTION NAME", {
    value = form_state.name,
    placeholder = "(required)",
    width = 30,
  })

  -- Server/Database File Path (inline input)
  local path_label = is_sqlite and "     DATABASE FILE  " or "     SERVER         "
  cb:labeled_input("server_path", path_label, {
    value = form_state.server_path,
    placeholder = "(required)",
    width = 30,
  })

  -- Port (inline input, not for SQLite)
  if not is_sqlite then
    local port_str = form_state.port and tostring(form_state.port) or (default_port and tostring(default_port) or "")
    cb:labeled_input("port", "     PORT           ", {
      value = port_str,
      placeholder = default_port and tostring(default_port) or "(default)",
      width = 8,
    })
  end

  -- Database (inline input, not for SQLite)
  if not is_sqlite then
    cb:labeled_input("database", "     DATABASE       ", {
      value = form_state.database,
      placeholder = "(optional)",
      width = 25,
    })
  end

  cb:blank()

  -- Authentication dropdown (not for SQLite)
  if not is_sqlite then
    local auth_opts = AUTH_TYPES[form_state.db_type] or {}
    local auth_options = {}
    for _, a in ipairs(auth_opts) do
      table.insert(auth_options, { value = a.id, label = a.label })
    end
    cb:dropdown("auth_type", {
      label = "  AUTHENTICATION",
      options = auth_options,
      value = form_state.auth_type,
      width = 26,
    })

    -- Username/Password (inline inputs, conditional)
    if needs_auth_creds then
      cb:labeled_input("username", "     USERNAME       ", {
        value = form_state.username,
        placeholder = "(required)",
        width = 20,
      })
      cb:labeled_input("password", "     PASSWORD       ", {
        value = form_state.password,
        placeholder = "(required)",
        width = 20,
      })
    end
    cb:blank()
  end

  -- Options section (toggles)
  cb:styled("  OPTIONS", "section")
  local fav_checkbox = form_state.favorite and "[x]" or "[ ]"
  local auto_checkbox = form_state.auto_connect and "[x]" or "[ ]"

  cb:spans({
    { text = "  ", style = "text" },
    { text = "f", style = "key" },
    { text = "  " .. fav_checkbox .. " ", style = form_state.favorite and "success" or "muted" },
    { text = "★", style = "warning" },
    { text = " Favorite", style = "muted" },
  })

  cb:spans({
    { text = "  ", style = "text" },
    { text = "a", style = "key" },
    { text = "  " .. auto_checkbox .. " ", style = form_state.auto_connect and "success" or "muted" },
    { text = "⚡", style = "warning" },
    { text = " Auto-connect", style = "muted" },
  })
  cb:blank()

  -- Hints
  if path_hint ~= "" then
    cb:styled("  " .. path_hint, "hint")
    cb:blank()
  end

  -- Actions section
  cb:styled("  ───────────────────────────────────────────", "muted")
  cb:spans({
    { text = "  ", style = "text" },
    { text = "j/k", style = "key" },
    { text = " Navigate  ", style = "muted" },
    { text = "Enter", style = "key" },
    { text = " Edit  ", style = "muted" },
    { text = "Esc", style = "key" },
    { text = " Confirm", style = "muted" },
  })
  cb:spans({
    { text = "  ", style = "text" },
    { text = "s", style = "key" },
    { text = "   Save    ", style = "muted" },
    { text = "T", style = "key" },
    { text = " Test  ", style = "muted" },
    { text = "b", style = "key" },
    { text = " Back  ", style = "muted" },
    { text = "q", style = "key" },
    { text = " Close", style = "muted" },
  })
  cb:blank()

  local title = is_edit and " Edit Connection " or " New Connection "

  -- Get keymaps from config
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  -- Build keymaps table - these work in normal mode alongside input navigation
  local keymaps = {}
  keymaps[common.close or "q"] = function() AddServerUI.close() end
  keymaps[km.back or "b"] = function()
    if #connections_list > 0 then
      AddServerUI.show_connection_list()
    else
      AddServerUI.close()
    end
  end
  -- Note: 't' and 'A' keymaps removed - now using inline dropdowns
  keymaps[km.toggle_favorite or "f"] = function()
    AddServerUI._sync_inputs_to_form_state(form_state)
    form_state.favorite = not form_state.favorite
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.toggle_auto_connect or "a"] = function()
    AddServerUI._sync_inputs_to_form_state(form_state)
    form_state.auto_connect = not form_state.auto_connect
    if form_state.auto_connect then
      form_state.favorite = true
    end
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.save or "s"] = function()
    AddServerUI._sync_inputs_to_form_state(form_state)
    AddServerUI.save_connection(form_state, edit_connection)
  end
  keymaps[km.test or "T"] = function()
    AddServerUI._sync_inputs_to_form_state(form_state)
    AddServerUI.test_connection(form_state)
  end
  keymaps["?"] = function() AddServerUI.show_form_controls() end

  -- Create float with styled content and input support
  current_float = UiFloat.create(nil, {
    title = title,
    title_pos = "center",
    footer = "? = Controls",
    border = "rounded",
    width = 55,
    min_height = 18,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
    content_builder = cb,
    enable_inputs = true,
  })

  -- Handle dropdown changes
  current_float:on_dropdown_change(function(key, value)
    AddServerUI._sync_inputs_to_form_state(form_state)

    if key == "db_type" then
      -- Database type changed - update auth type to default for new type
      form_state.db_type = value
      local auth_opts = AUTH_TYPES[value]
      if auth_opts and #auth_opts > 0 then
        form_state.auth_type = auth_opts[1].id
      end
      -- Clear credentials when switching db types
      if value == "sqlite" or form_state.auth_type ~= "sql" then
        form_state.username = ""
        form_state.password = ""
      end
      -- Refresh form to show/hide auth fields
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)

    elseif key == "auth_type" then
      -- Auth type changed
      form_state.auth_type = value
      -- Clear credentials when switching to non-SQL auth
      if value ~= "sql" then
        form_state.username = ""
        form_state.password = ""
      end
      -- Refresh form to show/hide credential fields
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Sync input field values back to form_state
---@param form_state table Form state to update
function AddServerUI._sync_inputs_to_form_state(form_state)
  if not current_float then return end
  
  local values = current_float:get_all_input_values()
  if values.name then form_state.name = values.name end
  if values.server_path then form_state.server_path = values.server_path end
  if values.database then form_state.database = values.database end
  if values.username then form_state.username = values.username end
  if values.password then form_state.password = values.password end
  if values.port then
    local port_num = tonumber(values.port)
    form_state.port = port_num
  end
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
