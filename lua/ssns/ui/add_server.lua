---@class AddServerUI
---Floating UI for adding and managing server connections
local AddServerUI = {}

local UiFloat = require('ssns.ui.float')
local Connections = require('ssns.connections')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')

-- Current state
local current_float = nil
local current_screen = "list"  -- "list" or "new"
local selected_index = 1
local connections_list = {}

-- Highlight namespace
local ns_id = vim.api.nvim_create_namespace("ssns_add_server")

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

---Apply highlights to a buffer
---@param bufnr number Buffer number
---@param highlights table[] Array of {line, col_start, col_end, hl_group}
local function apply_highlights(bufnr, highlights)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl[4], hl[1], hl[2], hl[3])
  end
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

  -- Build display lines
  local lines = {}
  local highlights = {}

  if #connections_list == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No saved connections")
    table.insert(lines, "")
    table.insert(lines, "  Press n to create a new connection")
    table.insert(lines, "")

    -- Highlights
    table.insert(highlights, {1, 0, -1, "Comment"})
    table.insert(highlights, {3, 8, 9, "Special"})  -- 'n' key
  else
    table.insert(lines, "")

    for i, conn in ipairs(connections_list) do
      local in_tree = is_in_tree(conn.name)
      local _, icon = get_type_info(conn.type or "sqlserver")

      -- Selection indicator
      local prefix = i == selected_index and "  " or "   "

      -- Build status indicators
      local indicators = ""
      if conn.favorite or conn.auto_connect then
        indicators = indicators .. " ★"
      end
      if conn.auto_connect then
        indicators = indicators .. "⚡"
      end
      if in_tree then
        indicators = indicators .. " [active]"
      end

      local line = string.format("%s%s %s%s", prefix, icon, conn.name, indicators)
      table.insert(lines, line)

      local line_idx = #lines - 1
      if i == selected_index then
        table.insert(highlights, {line_idx, 0, -1, "CursorLine"})
        table.insert(highlights, {line_idx, 2, 5, "Function"})  -- Icon
      else
        table.insert(highlights, {line_idx, 3, 6, "Comment"})  -- Icon dimmed
      end

      -- Highlight indicators
      if conn.favorite or conn.auto_connect then
        local star_pos = line:find("★")
        if star_pos then
          table.insert(highlights, {line_idx, star_pos - 1, star_pos + 2, "WarningMsg"})
        end
      end
      if in_tree then
        local active_pos = line:find("%[active%]")
        if active_pos then
          table.insert(highlights, {line_idx, active_pos - 1, -1, "DiagnosticOk"})
        end
      end
    end

    table.insert(lines, "")
  end

  -- Help section
  table.insert(lines, "  ───────────────────────────────────────────")
  local sep_line = #lines - 1
  table.insert(highlights, {sep_line, 0, -1, "Comment"})

  table.insert(lines, "")
  table.insert(lines, "  a Enter   Add to tree       n   New")
  table.insert(lines, "  e         Edit              d   Delete")
  table.insert(lines, "  f *       Toggle favorite   q   Close")
  table.insert(lines, "  j k       Navigate")
  table.insert(lines, "")

  -- Highlight keybinds
  for i = sep_line + 2, #lines - 2 do
    -- Highlight key letters (first column of keys)
    table.insert(highlights, {i, 2, 10, "Special"})
    table.insert(highlights, {i, 24, 32, "Special"})
  end

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

  -- Create floating window
  current_float = UiFloat.create(lines, {
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

  -- Apply highlights after window creation
  if current_float and current_float:is_valid() then
    apply_highlights(current_float.bufnr, highlights)

    -- Position cursor on selected item
    if #connections_list > 0 then
      current_float:set_cursor(1 + selected_index, 0)
    end
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
    local UiTree = require('ssns.ui.tree')
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

  -- Build form lines
  local lines = {}
  local highlights = {}
  local line_num = 0

  -- Server Type section
  table.insert(lines, "")
  line_num = line_num + 1
  table.insert(lines, "  SERVER TYPE")
  table.insert(highlights, {line_num, 2, -1, "Title"})
  line_num = line_num + 1

  table.insert(lines, string.format("  %s %s", type_icon, type_label))
  table.insert(highlights, {line_num, 2, 5, "Function"})
  table.insert(highlights, {line_num, 5, -1, "String"})
  line_num = line_num + 1

  table.insert(lines, "  Press t to change")
  table.insert(highlights, {line_num, 8, 9, "Special"})
  table.insert(highlights, {line_num, 0, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "")
  line_num = line_num + 1

  -- Connection Name section
  table.insert(lines, "  CONNECTION NAME")
  table.insert(highlights, {line_num, 2, -1, "Title"})
  line_num = line_num + 1

  local name_display = form_state.name ~= "" and form_state.name or "(not set)"
  table.insert(lines, "  " .. name_display)
  if form_state.name ~= "" then
    table.insert(highlights, {line_num, 2, -1, "String"})
  else
    table.insert(highlights, {line_num, 2, -1, "Comment"})
  end
  line_num = line_num + 1

  table.insert(lines, "  Press n to set")
  table.insert(highlights, {line_num, 8, 9, "Special"})
  table.insert(highlights, {line_num, 0, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "")
  line_num = line_num + 1

  -- Server Path section
  local path_title = is_sqlite and "  DATABASE FILE" or "  SERVER"
  table.insert(lines, path_title)
  table.insert(highlights, {line_num, 2, -1, "Title"})
  line_num = line_num + 1

  local path_display = form_state.server_path ~= "" and form_state.server_path or "(not set)"
  table.insert(lines, "  " .. path_display)
  if form_state.server_path ~= "" then
    table.insert(highlights, {line_num, 2, -1, "String"})
  else
    table.insert(highlights, {line_num, 2, -1, "Comment"})
  end
  line_num = line_num + 1

  table.insert(lines, "  Press p to set")
  table.insert(highlights, {line_num, 8, 9, "Special"})
  table.insert(highlights, {line_num, 0, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "  " .. path_hint)
  table.insert(highlights, {line_num, 0, -1, "DiagnosticHint"})
  line_num = line_num + 1

  table.insert(lines, "")
  line_num = line_num + 1

  -- Database section (not for SQLite)
  if not is_sqlite then
    table.insert(lines, "  DATABASE (optional)")
    table.insert(highlights, {line_num, 2, -1, "Title"})
    line_num = line_num + 1

    local db_display = form_state.database ~= "" and form_state.database or "(default)"
    table.insert(lines, "  " .. db_display)
    if form_state.database ~= "" then
      table.insert(highlights, {line_num, 2, -1, "String"})
    else
      table.insert(highlights, {line_num, 2, -1, "Comment"})
    end
    line_num = line_num + 1

    table.insert(lines, "  Press D to set")
    table.insert(highlights, {line_num, 8, 9, "Special"})
    table.insert(highlights, {line_num, 0, -1, "Comment"})
    line_num = line_num + 1

    table.insert(lines, "")
    line_num = line_num + 1
  end

  -- Authentication section (not for SQLite)
  if not is_sqlite then
    table.insert(lines, "  AUTHENTICATION")
    table.insert(highlights, {line_num, 2, -1, "Title"})
    line_num = line_num + 1

    table.insert(lines, "  " .. auth_label)
    table.insert(highlights, {line_num, 2, -1, "String"})
    line_num = line_num + 1

    table.insert(lines, "  Press A to change")
    table.insert(highlights, {line_num, 8, 9, "Special"})
    table.insert(highlights, {line_num, 0, -1, "Comment"})
    line_num = line_num + 1

    -- Show username/password fields for SQL auth
    if needs_auth_creds then
      table.insert(lines, "")
      line_num = line_num + 1

      local user_display = form_state.username ~= "" and form_state.username or "(not set)"
      table.insert(lines, "  Username: " .. user_display)
      if form_state.username ~= "" then
        table.insert(highlights, {line_num, 12, -1, "String"})
      else
        table.insert(highlights, {line_num, 12, -1, "Comment"})
      end
      line_num = line_num + 1

      local pass_display = form_state.password ~= "" and string.rep("*", #form_state.password) or "(not set)"
      table.insert(lines, "  Password: " .. pass_display)
      if form_state.password ~= "" then
        table.insert(highlights, {line_num, 12, -1, "String"})
      else
        table.insert(highlights, {line_num, 12, -1, "Comment"})
      end
      line_num = line_num + 1

      table.insert(lines, "  Press u/P to set credentials")
      table.insert(highlights, {line_num, 8, 9, "Special"})
      table.insert(highlights, {line_num, 10, 11, "Special"})
      table.insert(highlights, {line_num, 0, -1, "Comment"})
      line_num = line_num + 1
    end

    table.insert(lines, "")
    line_num = line_num + 1
  end

  -- Options section
  table.insert(lines, "  OPTIONS")
  table.insert(highlights, {line_num, 2, -1, "Title"})
  line_num = line_num + 1

  local fav_checkbox = form_state.favorite and "[x]" or "[ ]"
  local auto_checkbox = form_state.auto_connect and "[x]" or "[ ]"

  table.insert(lines, string.format("  %s ★ Favorite          Show in tree on startup", fav_checkbox))
  table.insert(highlights, {line_num, 2, 5, form_state.favorite and "DiagnosticOk" or "Comment"})
  table.insert(highlights, {line_num, 6, 7, "WarningMsg"})
  table.insert(highlights, {line_num, 26, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, string.format("  %s ⚡ Auto-connect      Connect automatically", auto_checkbox))
  table.insert(highlights, {line_num, 2, 5, form_state.auto_connect and "DiagnosticOk" or "Comment"})
  table.insert(highlights, {line_num, 6, 8, "DiagnosticWarn"})
  table.insert(highlights, {line_num, 26, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "  Press f or a to toggle")
  table.insert(highlights, {line_num, 8, 9, "Special"})
  table.insert(highlights, {line_num, 13, 14, "Special"})
  table.insert(highlights, {line_num, 0, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "")
  line_num = line_num + 1

  -- Actions section
  table.insert(lines, "  ───────────────────────────────────────────")
  table.insert(highlights, {line_num, 0, -1, "Comment"})
  line_num = line_num + 1

  table.insert(lines, "")
  line_num = line_num + 1
  table.insert(lines, "  s   Save connection       T   Test connection")
  table.insert(highlights, {line_num, 2, 3, "Special"})
  table.insert(highlights, {line_num, 28, 29, "Special"})
  line_num = line_num + 1
  table.insert(lines, "  b   Back to list          q   Close")
  table.insert(highlights, {line_num, 2, 3, "Special"})
  table.insert(highlights, {line_num, 28, 29, "Special"})
  line_num = line_num + 1
  table.insert(lines, "")

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

  -- Create fresh float with keymaps
  current_float = UiFloat.create(lines, {
    title = title,
    title_pos = "center",
    border = "rounded",
    min_width = 52,
    min_height = 20,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
  })

  -- Apply highlights after window creation
  if current_float and current_float:is_valid() then
    apply_highlights(current_float.bufnr, highlights)
  end
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
          local UiTree = require('ssns.ui.tree')
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
