---@class UiQuery
---Query buffer management for SSNS
local UiQuery = {}

local QueryHistory = require('ssns.query_history')
local KeymapManager = require('ssns.keymap_manager')
local Spinner = require('ssns.async.spinner')

-- Load submodules
local QueryExport = require('ssns.ui.core.query.export')
local QueryProcedures = require('ssns.ui.core.query.procedures')
local QueryResults = require('ssns.ui.core.query.results')
local QueryExecute = require('ssns.ui.core.query.execute')

---Track query buffers
---@type table<number, {server: ServerClass|string, database: DbClass|string?, last_database: string?, connecting: boolean?, connecting_spinner: TextSpinner?, server_name: string?, database_name: string?}>
UiQuery.query_buffers = {}

---Track buffer counter for unique names
---@type table<string, number>
UiQuery.buffer_counter = {}

---Track auto-save debounce timers per buffer
---@type table<number, userdata>
UiQuery.auto_save_timers = {}

---Store query results per buffer for export and re-display
---@type table<number, {resultSets: table[]?, sql: string?, execution_time_ms: number?, metadata: table?, result_set_ranges: table[]?}>
UiQuery.buffer_results = {}

---Store results window height per query buffer for restore on toggle
---@type table<number, number>
UiQuery.buffer_results_window_height = {}

-- Initialize submodules with parent reference
QueryExport._init(UiQuery)
QueryProcedures._init(UiQuery)
QueryResults._init(UiQuery)
QueryExecute._init(UiQuery, QueryResults)

-- ============================================================================
-- Buffer Management
-- ============================================================================

---Generate a unique buffer name
---@param object_name string? The object name (table, view, etc.)
---@param server ServerClass? The server
---@param database DbClass? The database
---@return string buffer_name
function UiQuery.generate_buffer_name(object_name, server, database)
  local base_name = object_name or "query"

  -- Initialize counter for this base name if needed
  if not UiQuery.buffer_counter[base_name] then
    UiQuery.buffer_counter[base_name] = 0
  end

  -- Find a unique buffer name by incrementing counter until we find one that doesn't exist
  local buf_name
  local max_attempts = 1000  -- Prevent infinite loop

  for _ = 1, max_attempts do
    UiQuery.buffer_counter[base_name] = UiQuery.buffer_counter[base_name] + 1
    local count = UiQuery.buffer_counter[base_name]
    buf_name = string.format("[%s-%d]", base_name, count)

    -- Use vim.fn.bufexists to properly check if buffer name is taken
    if vim.fn.bufexists(buf_name) == 0 then
      return buf_name
    end
  end

  -- Fallback: use timestamp to guarantee uniqueness
  return string.format("[%s-%d]", base_name, os.time())
end

---Prepend USE statement for SQL Server databases
---@param sql string The SQL to prepend USE statement to
---@param server ServerClass? The server
---@param database DbClass? The database
---@return string sql SQL with USE statement prepended if applicable
function UiQuery.prepend_use_statement(sql, server, database)
  -- Only add USE statement for SQL Server and if database is specified
  if not server or not database then
    return sql
  end

  local adapter = server:get_adapter()
  if not adapter or adapter.db_type ~= "sqlserver" then
    return sql
  end

  -- Prepend USE [database];
  return string.format("USE [%s];\n\n%s", database.db_name, sql)
end

---Find or create a window for query buffers (not the SSNS tree window)
---@return number winid
function UiQuery.focus_query_window()
  local ssns_buffer = require('ssns.ui.core.buffer')

  -- Look for an existing query buffer window (not SSNS tree, not special buffers)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')

    -- Skip SSNS tree window
    if bufnr == ssns_buffer.bufnr then
      goto continue
    end

    -- Skip special buffers (nofile, help, etc.)
    if buftype ~= '' and buftype ~= 'acwrite' then
      goto continue
    end

    -- Found a suitable window (normal buffer or query buffer)
    if modifiable then
      vim.api.nvim_set_current_win(win)
      return win
    end

    ::continue::
  end

  -- No suitable window found, create new one
  -- Determine position based on SSNS tree position
  local Config = require('ssns.config')
  local ui_config = Config.get_ui()
  local win_pos = ui_config.position == 'left' and 'botright' or 'topleft'

  vim.cmd(win_pos .. ' new')
  return vim.api.nvim_get_current_win()
end

---Create a new query buffer with optional SQL
---@param server ServerClass? The server to associate with this query
---@param database DbClass? The database to associate with this query
---@param sql string? Optional SQL to populate the buffer
---@param object_name string? The object name for the buffer title
---@param history_buffer_id string? Optional history buffer ID to continue existing history
---@return number bufnr The buffer number
function UiQuery.create_query_buffer(server, database, sql, object_name, history_buffer_id)
  -- Focus or create query window
  UiQuery.focus_query_window()

  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(true, false)

  -- Generate unique buffer name
  local buf_name = UiQuery.generate_buffer_name(object_name, server, database)
  vim.api.nvim_buf_set_name(bufnr, buf_name)

  -- Set filetype to sql for syntax highlighting
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'sql')
  vim.api.nvim_buf_set_option(bufnr, 'buftype', '')

  -- Enable line numbers
  vim.api.nvim_buf_set_option(bufnr, 'buflisted', true)

  -- Track this buffer with initial database context
  UiQuery.query_buffers[bufnr] = {
    server = server,
    database = database,
    last_database = database and database.db_name or nil,  -- Initial context from parent
  }

  -- Set buffer variable for completion source to identify database connection
  -- Handle both ServerClass objects and string names (from history)
  if server and database then
    local server_name = type(server) == "string" and server or server.name
    local db_name = type(database) == "string" and database or database.db_name
    vim.api.nvim_buf_set_var(bufnr, 'ssns_db_key', string.format("%s:%s", server_name, db_name))
  end

  -- Set history buffer ID if provided (for continuing history from loaded queries)
  if history_buffer_id then
    vim.api.nvim_buf_set_var(bufnr, 'ssns_history_buffer_id', history_buffer_id)
  end

  -- Set buffer-local keymaps
  UiQuery.setup_query_keymaps(bufnr)

  -- Setup semantic highlighting for this buffer
  local SemanticHighlighter = require('ssns.highlighting.semantic')
  SemanticHighlighter.setup_buffer(bufnr)

  -- Setup auto-save on buffer edits (if enabled)
  UiQuery.setup_buffer_auto_save(bufnr)

  -- If SQL provided, prepend USE statement and set it in the buffer
  if sql then
    local final_sql = UiQuery.prepend_use_statement(sql, server, database)
    local lines = vim.split(final_sql, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  -- Switch to the new buffer in the current window
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Set modifiable
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)

  -- Enable line numbers in this window
  vim.api.nvim_win_set_option(0, 'number', true)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)

  return bufnr
end

-- ============================================================================
-- Keymaps and Controls
-- ============================================================================

---Show controls popup for query buffer
function UiQuery.show_query_controls()
  local UiFloat = require('nvim-float.window')
  local km = KeymapManager.get_group("query")

  local controls = {
    {
      header = "Execute",
      keys = {
        { key = km.execute or "Leader-r", desc = "Execute query (buffer)" },
        { key = km.execute or "Leader-r", desc = "Execute selection (visual)" },
        { key = km.execute_statement or "Leader-R", desc = "Execute statement under cursor" },
      },
    },
    {
      header = "Navigation",
      keys = {
        { key = km.go_to or "gd", desc = "Go to object in tree" },
        { key = km.view_definition or "K", desc = "View object definition" },
        { key = km.view_metadata or "M", desc = "View object metadata" },
      },
    },
    {
      header = "Connection",
      keys = {
        { key = km.attach_connection or "A-s", desc = "Attach buffer to connection" },
        { key = km.change_connection or "A-S", desc = "Change connection (hierarchical)" },
        { key = km.change_database or "A-d", desc = "Change database" },
      },
    },
    {
      header = "Actions",
      keys = {
        { key = km.toggle_results or "C-r", desc = "Toggle results window" },
        { key = km.save or "Leader-s", desc = "Save query" },
        { key = km.expand_asterisk or "Leader-ce", desc = "Expand asterisk to columns" },
        { key = km.new or "C-n", desc = "New query buffer" },
        { key = km.show_history or "Leader-@", desc = "Show query history" },
      },
    },
  }

  UiFloat._show_controls_popup(controls)
end

---Setup keymaps for query buffer
---@param bufnr number The buffer number
function UiQuery.setup_query_keymaps(bufnr)
  local km = KeymapManager.get_group("query")

  local keymaps = {
    -- Execute query (normal mode - entire buffer)
    { mode = "n", lhs = km.execute or "<Leader>r", rhs = function()
      UiQuery.execute_query(bufnr, false)
    end, desc = "Execute query" },

    -- Execute query (visual mode - selection)
    { mode = "v", lhs = km.execute_selection or km.execute or "<Leader>r", rhs = function()
      UiQuery.execute_query(bufnr, true)
    end, desc = "Execute selected query" },

    -- Execute query under cursor
    { mode = "n", lhs = km.execute_statement or "<Leader>R", rhs = function()
      UiQuery.execute_statement_under_cursor(bufnr)
    end, desc = "Execute statement under cursor" },

    -- Save query
    { mode = "n", lhs = km.save or "<Leader>s", rhs = function()
      UiQuery.save_query(bufnr)
    end, desc = "Save query" },

    -- Expand asterisk
    { mode = "n", lhs = km.expand_asterisk or "<Leader>ce", rhs = function()
      local ExpandAsterisk = require('ssns.features.expand_asterisk')
      ExpandAsterisk.expand_asterisk_at_cursor()
    end, desc = "Expand asterisk (Columns Expand)" },

    -- New query buffer (inherits current database context)
    { mode = "n", lhs = km.new or "<C-n>", rhs = function()
      UiQuery.new_query_from_buffer(bufnr)
    end, desc = "New query buffer" },

    -- Show query history
    { mode = "n", lhs = km.show_history or "<Leader>@", rhs = function()
      local UiHistory = require('ssns.ui.panels.history')
      UiHistory.show_history()
    end, desc = "Show query history" },

    -- Go to object under cursor in tree
    { mode = "n", lhs = km.go_to or "gd", rhs = function()
      local GoTo = require('ssns.features.go_to')
      GoTo.go_to_object_at_cursor()
    end, desc = "Go to object in tree" },

    -- View object definition
    { mode = "n", lhs = km.view_definition or "K", rhs = function()
      local ViewDefinition = require('ssns.features.view_definition')
      ViewDefinition.view_definition_at_cursor()
    end, desc = "View object definition" },

    -- View object metadata
    { mode = "n", lhs = km.view_metadata or "M", rhs = function()
      local ViewMetadata = require('ssns.features.view_metadata')
      ViewMetadata.view_metadata_at_cursor()
    end, desc = "View object metadata" },

    -- Toggle results window
    { mode = "n", lhs = km.toggle_results or "<C-r>", rhs = function()
      UiQuery.toggle_results()
    end, desc = "Toggle results window" },

    -- Cancel running query
    { mode = "n", lhs = km.cancel or "<C-c>", rhs = function()
      local QueryExecute = require('ssns.ui.core.query.execute')
      if QueryExecute.is_query_running(bufnr) then
        QueryExecute.cancel_query(bufnr)
      end
    end, desc = "Cancel running query" },

    -- Attach connection (flat list)
    { mode = "n", lhs = km.attach_connection or "<A-s>", rhs = function()
      local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
      ConnectionPicker.show(bufnr)
    end, desc = "Attach buffer to connection" },

    -- Change connection (hierarchical picker)
    { mode = "n", lhs = km.change_connection or "<A-S>", rhs = function()
      local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
      ConnectionPicker.show_hierarchical(bufnr)
    end, desc = "Change connection (server then database)" },

    -- Change database only
    { mode = "n", lhs = km.change_database or "<A-d>", rhs = function()
      local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
      ConnectionPicker.show_database_picker(bufnr)
    end, desc = "Change database" },

    -- Show controls
    { mode = "n", lhs = "?", rhs = function()
      UiQuery.show_query_controls()
    end, desc = "Show controls" },
  }

  KeymapManager.set_multiple(bufnr, keymaps, true)
  KeymapManager.mark_group_active(bufnr, "query")

  -- Setup cast keymaps for visual mode type conversions
  local CastCommands = require('ssns.commands.cast')
  CastCommands.setup_keymaps(bufnr)
end

-- ============================================================================
-- Auto-save
-- ============================================================================

---Setup auto-save on buffer edits (debounced)
---@param bufnr number The buffer number
function UiQuery.setup_buffer_auto_save(bufnr)
  local Config = require('ssns.config')
  local config = Config.get()
  local delay_ms = config.query_history and config.query_history.buffer_auto_save_delay_ms or -1

  -- Skip if disabled
  if delay_ms < 0 then
    return
  end

  -- Create autocmd namespace for this buffer
  local augroup = vim.api.nvim_create_augroup('ssns_auto_save_' .. bufnr, { clear = true })

  -- Debounce function
  local function trigger_auto_save()
    -- Cancel existing timer for this buffer
    if UiQuery.auto_save_timers[bufnr] then
      UiQuery.auto_save_timers[bufnr]:stop()
      UiQuery.auto_save_timers[bufnr] = nil
    end

    -- Get buffer info
    local buffer_info = UiQuery.query_buffers[bufnr]
    if not buffer_info or not buffer_info.server then
      return
    end

    -- Create new timer
    local timer = vim.loop.new_timer()
    UiQuery.auto_save_timers[bufnr] = timer

    timer:start(delay_ms, 0, vim.schedule_wrap(function()
      -- Check if buffer still exists
      if not vim.api.nvim_buf_is_valid(bufnr) then
        if UiQuery.auto_save_timers[bufnr] then
          UiQuery.auto_save_timers[bufnr]:stop()
          UiQuery.auto_save_timers[bufnr] = nil
        end
        return
      end

      -- Get buffer content
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Get buffer name
      local buffer_name = vim.api.nvim_buf_get_name(bufnr)
      if buffer_name == "" then
        buffer_name = string.format("Query Buffer %d", bufnr)
      else
        buffer_name = vim.fn.fnamemodify(buffer_name, ':t')
      end

      -- Get server name (handle both ServerClass objects and strings)
      local server_name = type(buffer_info.server) == "string"
        and buffer_info.server
        or (buffer_info.server and buffer_info.server.name)

      if not server_name then
        -- Clear timer reference and skip if no server name
        UiQuery.auto_save_timers[bufnr] = nil
        return
      end

      -- Get current database context (handle both DbClass objects and strings)
      local current_database = buffer_info.last_database
        or (type(buffer_info.database) == "string" and buffer_info.database)
        or (buffer_info.database and buffer_info.database.db_name)
        or "master"

      -- Add auto-save entry
      QueryHistory.add_auto_save_entry(
        bufnr,
        buffer_name,
        content,
        server_name,
        current_database
      )

      -- Clear timer reference
      UiQuery.auto_save_timers[bufnr] = nil
    end))
  end

  -- Setup autocmds for text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = bufnr,
    callback = trigger_auto_save,
  })

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      -- Cancel any pending timer
      if UiQuery.auto_save_timers[bufnr] then
        UiQuery.auto_save_timers[bufnr]:stop()
        UiQuery.auto_save_timers[bufnr] = nil
      end
      -- Clean up the autocmd group
      vim.api.nvim_del_augroup_by_id(augroup)
    end,
  })
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

---Save query to file
---@param bufnr number The buffer number
function UiQuery.save_query(bufnr)
  -- Get buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local sql = table.concat(lines, "\n")

  -- Prompt for filename
  local filename = vim.fn.input("Save query as: ", "", "file")

  if filename == "" then
    return
  end

  -- Write to file
  local file = io.open(filename, "w")
  if not file then
    vim.notify(string.format("SSNS: Failed to save query to %s", filename), vim.log.levels.ERROR)
    return
  end

  file:write(sql)
  file:close()

  vim.notify(string.format("SSNS: Query saved to %s", filename), vim.log.levels.INFO)
end

---Check if buffer is a query buffer
---@param bufnr number The buffer number
---@return boolean
function UiQuery.is_query_buffer(bufnr)
  return UiQuery.query_buffers[bufnr] ~= nil
end

---Get server for query buffer
---@param bufnr number The buffer number
---@return ServerClass?
function UiQuery.get_server(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  return info and info.server
end

---Get database for query buffer
---@param bufnr number The buffer number
---@return DbClass?
function UiQuery.get_database(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  return info and info.database
end

---Check if buffer is currently connecting to server
---@param bufnr number The buffer number
---@return boolean
function UiQuery.is_connecting(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  return info and info.connecting == true
end

---Get connecting status info for buffer (for lualine)
---@param bufnr number The buffer number
---@return {connecting: boolean, server_name: string?, database_name: string?, spinner_frame: string?}?
function UiQuery.get_connecting_info(bufnr)
  local info = UiQuery.query_buffers[bufnr]
  if not info then return nil end

  if not info.connecting then
    return { connecting = false }
  end

  -- Get spinner frame from TextSpinner
  local spinner_frame = "⠋"
  if info.connecting_spinner then
    spinner_frame = info.connecting_spinner:get_frame()
  end

  return {
    connecting = true,
    server_name = info.server_name,
    database_name = info.database_name,
    spinner_frame = spinner_frame,
  }
end

---Start connecting state for buffer (with spinner animation)
---@param bufnr number The buffer number
---@param server_name string Server name being connected to
---@param database_name string? Database name
function UiQuery.start_connecting(bufnr, server_name, database_name)
  local info = UiQuery.query_buffers[bufnr]
  if not info then return end

  info.connecting = true
  info.server_name = server_name
  info.database_name = database_name

  -- Create TextSpinner with callback to refresh lualine
  info.connecting_spinner = Spinner.create_text_spinner({
    on_tick = function()
      -- Check if buffer still exists and is still connecting
      local buf_info = UiQuery.query_buffers[bufnr]
      if not buf_info or not buf_info.connecting then
        if buf_info and buf_info.connecting_spinner then
          buf_info.connecting_spinner:stop()
          buf_info.connecting_spinner = nil
        end
        return
      end

      -- Refresh lualine
      vim.cmd('redrawstatus')
    end,
  })

  -- Start the spinner animation (80ms interval for smooth animation)
  info.connecting_spinner:start(80)
end

---Stop connecting state for buffer
---@param bufnr number The buffer number
---@param server ServerClass? Connected server (nil if failed)
---@param database DbClass? Connected database (nil if failed)
function UiQuery.stop_connecting(bufnr, server, database)
  local info = UiQuery.query_buffers[bufnr]
  if not info then return end

  -- Stop TextSpinner
  if info.connecting_spinner then
    info.connecting_spinner:stop()
    info.connecting_spinner = nil
  end

  -- Clear connecting state
  info.connecting = false

  -- Update server/database if connection succeeded
  if server then
    info.server = server
    if database then
      info.database = database
      info.last_database = database.db_name
    elseif info.database_name then
      -- Try to find database on the connected server
      local db = server:find_database(info.database_name)
      if db then
        info.database = db
        info.last_database = db.db_name
      end
    end

    -- Update buffer variable for completion
    local srv_name = type(server) == "string" and server or server.name
    local db_name = info.last_database or info.database_name
    if srv_name and db_name then
      pcall(vim.api.nvim_buf_set_var, bufnr, 'ssns_db_key', string.format("%s:%s", srv_name, db_name))
    end
  end

  -- Clear temp names
  info.server_name = nil
  info.database_name = nil

  -- Final lualine refresh
  vim.cmd('redrawstatus')
end

---Create a new query buffer using context from an existing query buffer
---@param source_bufnr number The source buffer number
function UiQuery.new_query_from_buffer(source_bufnr)
  local Cache = require('ssns.cache')
  local buffer_info = UiQuery.query_buffers[source_bufnr]

  local server, database

  if buffer_info then
    server = buffer_info.server

    -- Try to get database from last_database (updated after query execution)
    if buffer_info.last_database and server and server.find_database then
      database = server:find_database(buffer_info.last_database)
    end

    -- Fallback to initial database association
    if not database then
      database = buffer_info.database
    end
  end

  -- Fallback to globally active database
  if not database then
    database = Cache.get_active_database()
    if database then
      server = database:get_server()
    end
  end

  -- Create new query buffer
  UiQuery.create_query_buffer(server, database, "", "Query")
end

-- ============================================================================
-- Delegated Functions (to submodules)
-- ============================================================================

-- Execute module delegation
UiQuery.execute_query = function(bufnr, visual)
  QueryExecute.execute_query(bufnr, visual)
end

UiQuery.execute_statement_under_cursor = function(bufnr)
  QueryExecute.execute_statement_under_cursor(bufnr)
end

UiQuery.display_error = function(error, sql, query_bufnr, selection_start_line)
  QueryExecute.display_error(error, sql, query_bufnr, selection_start_line)
end

-- Results module delegation
UiQuery.display_results = function(result, sql, execution_time_ms, query_bufnr)
  QueryResults.display_results(result, sql, execution_time_ms, query_bufnr)
end

UiQuery.toggle_results = function(query_bufnr)
  QueryResults.toggle_results(query_bufnr)
end

UiQuery.format_results_styled = function(resultSets, sql, execution_time_ms, query_metadata)
  return QueryResults.format_results_styled(resultSets, sql, execution_time_ms, query_metadata)
end

UiQuery.format_single_result_set_styled = function(result_set, columns_metadata, builder, results_config)
  return QueryResults.format_single_result_set_styled(result_set, columns_metadata, builder, results_config)
end

UiQuery.parse_divider_format = function(format, metadata)
  return QueryResults.parse_divider_format(format, metadata)
end

UiQuery.setup_results_keymaps = function(result_buf)
  QueryResults.setup_results_keymaps(result_buf)
end

UiQuery.show_results_controls = function()
  QueryResults.show_results_controls()
end

-- Export module delegation
UiQuery.results_to_csv = function(resultSets, result_set_index)
  return QueryExport.results_to_csv(resultSets, result_set_index)
end

UiQuery.export_results_to_csv = function(filepath)
  QueryExport.export_results_to_csv(filepath)
end

UiQuery.export_all_results_to_csv = function()
  QueryExport.export_all_results_to_csv()
end

UiQuery.yank_results_as_csv = function()
  QueryExport.yank_results_as_csv()
end

UiQuery.yank_all_results_as_csv = function()
  QueryExport.yank_all_results_as_csv()
end

-- Excel export functions
UiQuery.results_to_xlsx = function(resultSets, result_set_index, opts)
  return QueryExport.results_to_xlsx(resultSets, result_set_index, opts)
end

UiQuery.export_results_to_xlsx = function(filepath)
  QueryExport.export_results_to_xlsx(filepath)
end

UiQuery.export_all_results_to_xlsx = function()
  QueryExport.export_all_results_to_xlsx()
end

-- Smart export functions (respect config format, fallback to CSV)
UiQuery.export_results = function(filepath)
  QueryExport.export_results(filepath)
end

UiQuery.export_all_results = function()
  QueryExport.export_all_results()
end

UiQuery.is_xlsx_available = function()
  return QueryExport.is_xlsx_available()
end

UiQuery.get_buffer_results = function(query_bufnr)
  return QueryExport.get_buffer_results(query_bufnr)
end

UiQuery.clear_buffer_results = function(query_bufnr)
  QueryExport.clear_buffer_results(query_bufnr)
end

-- Procedures module delegation
UiQuery.is_stored_procedure_exec = function(sql)
  return QueryProcedures.is_stored_procedure_exec(sql)
end

UiQuery.parse_procedure_name = function(full_name)
  return QueryProcedures.parse_procedure_name(full_name)
end

UiQuery.execute_with_params = function(bufnr, sql, server, database_name)
  QueryProcedures.execute_with_params(bufnr, sql, server, database_name)
end

UiQuery.build_exec_statement = function(schema_name, proc_name, parameters, values)
  return QueryProcedures.build_exec_statement(schema_name, proc_name, parameters, values)
end

return UiQuery
