---@class UiQuery
---Query buffer management for SSNS
local UiQuery = {}

local QueryHistory = require('ssns.query_history')
local KeymapManager = require('ssns.keymap_manager')

---Track query buffers
---@type table<number, {server: ServerClass, database: DbClass?, last_database: string?}>
UiQuery.query_buffers = {}

---Track buffer counter for unique names
---@type table<string, number>
UiQuery.buffer_counter = {}

---Track auto-save debounce timers per buffer
---@type table<number, userdata>
UiQuery.auto_save_timers = {}

---Store last query results for export and re-display
---@type {resultSets: table[]?, sql: string?, execution_time_ms: number?, metadata: table?}?
UiQuery.last_results = nil

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
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
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

---Setup keymaps for query buffer
---@param bufnr number The buffer number
---Show controls popup for query buffer
function UiQuery.show_query_controls()
  local UiFloat = require('ssns.ui.core.float')
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
end

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

      -- Get current database context
      local current_database = buffer_info.last_database
        or (buffer_info.database and buffer_info.database.db_name)
        or "master"

      -- Add auto-save entry
      QueryHistory.add_auto_save_entry(
        bufnr,
        buffer_name,
        content,
        buffer_info.server.name,
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

---Execute query in buffer
---@param bufnr number The buffer number
---@param visual boolean Whether to execute visual selection
function UiQuery.execute_query(bufnr, visual)
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info then
    vim.notify("SSNS: Not a query buffer", vim.log.levels.ERROR)
    return
  end

  local server = buffer_info.server
  if not server then
    vim.notify("SSNS: No server associated with this query buffer", vim.log.levels.ERROR)
    return
  end

  if not server:is_connected() then
    vim.notify("SSNS: Server is not connected", vim.log.levels.ERROR)
    return
  end

  -- Get SQL to execute
  local sql
  if visual then
    -- Get visual selection
    local start_line = vim.fn.line("'<") - 1
    local end_line = vim.fn.line("'>")
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    sql = table.concat(lines, "\n")
  else
    -- Get entire buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- DEBUG: Show what we got from buffer
    -- vim.notify(string.format("DEBUG BUFFER: Read %d lines from buffer", #lines), vim.log.levels.INFO)
    --for i, line in ipairs(lines) do
      -- vim.notify(string.format("DEBUG BUFFER: Line %d: [%s] (len=%d)", i, line, #line), vim.log.levels.INFO)
    --end

    sql = table.concat(lines, "\n")

    -- DEBUG: Show concatenated result
    -- vim.notify(string.format("DEBUG BUFFER: Concatenated SQL length=%d", #sql), vim.log.levels.INFO)
    -- vim.notify(string.format("DEBUG BUFFER: SQL preview: %s", sql:sub(1, 100):gsub("\n", "\\n")), vim.log.levels.INFO)
  end

  -- Don't trim! We need to preserve exact line numbers for error reporting
  -- Just check if it's empty (only whitespace)
  if sql:match("^%s*$") then
    vim.notify("SSNS: No SQL to execute", vim.log.levels.WARN)
    return
  end

  -- Clear any previous error highlights in this buffer
  local ns_id = vim.api.nvim_create_namespace('ssns_sql_error')
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Execute query
  vim.notify("SSNS: Executing query...", vim.log.levels.INFO)

  -- Get buffer's current database context
  -- Priority: last_database > database.db_name > nil
  local buffer_db = buffer_info.last_database
  if not buffer_db and buffer_info.database then
    buffer_db = buffer_info.database.db_name
  end

  -- Execute with buffer context (handles USE statements and GO separators)
  local Connection = require('ssns.connection')
  local start_time = vim.loop.hrtime()
  local result, last_database = Connection.execute_with_buffer_context(
    server.connection_config,
    sql,
    buffer_db
  )
  local end_time = vim.loop.hrtime()
  local execution_time_ms = (end_time - start_time) / 1000000  -- Convert nanoseconds to milliseconds

  -- Update buffer state with last database used
  if last_database then
    buffer_info.last_database = last_database
    -- Update buffer variable for completion source
    vim.api.nvim_buf_set_var(bufnr, 'ssns_db_key', string.format("%s:%s", server.name, last_database))
  end

  -- Track query in history
  local buffer_name = vim.api.nvim_buf_get_name(bufnr)
  if buffer_name == "" then
    buffer_name = string.format("Query Buffer %d", bufnr)
  else
    buffer_name = vim.fn.fnamemodify(buffer_name, ':t')  -- Get filename only
  end

  local current_database = buffer_info.last_database
    or (buffer_info.database and buffer_info.database.db_name)
    or "master"

  -- Check if query succeeded
  if not result.success then
    -- Track error in history
    QueryHistory.add_entry(bufnr, buffer_name, {
      query = sql,
      server_name = server.name,
      database = current_database,
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      execution_time_ms = execution_time_ms,
      status = "error",
      error_message = result.error and result.error.message or "Unknown error",
      error_line = result.error and result.error.lineNumber or nil,
    })

    -- Display detailed error with structured information
    UiQuery.display_error(result.error, sql, bufnr)
    return
  end

  -- Track success in history
  local row_count = 0
  if result.resultSets and result.resultSets[1] and result.resultSets[1].rows then
    row_count = #result.resultSets[1].rows
  end

  QueryHistory.add_entry(bufnr, buffer_name, {
    query = sql,
    server_name = server.name,
    database = current_database,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    execution_time_ms = execution_time_ms,
    status = "success",
    row_count = row_count,
  })

  -- Track usage from query analysis
  local Config = require('ssns.config')
  local config = Config.get()

  if config.completion and config.completion.track_usage then
    local success, err = pcall(function()
      local UsageAnalyzer = require('ssns.completion.usage_analyzer')
      UsageAnalyzer.analyze_and_record(sql, {
        connection_config = server.connection_config
      })
    end)

    if not success then
      -- Silent failure - log only
      local Debug = require('ssns.debug')
      Debug.log("[USAGE] Query analysis error: " .. tostring(err))
    end
  end

  -- Display results with execution metadata
  UiQuery.display_results(result, sql, execution_time_ms)
end

---Execute statement under cursor
---@param bufnr number The buffer number
function UiQuery.execute_statement_under_cursor(bufnr)
  -- Find the SQL statement under cursor
  -- For now, just execute the current line
  -- TODO: Implement proper statement detection (find ; or GO boundaries)
  local cursor_line = vim.fn.line('.') - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, cursor_line, cursor_line + 1, false)

  if #lines == 0 then
    vim.notify("SSNS: No statement under cursor", vim.log.levels.WARN)
    return
  end

  local sql = lines[1]:match("^%s*(.-)%s*$")

  if sql == "" then
    vim.notify("SSNS: No SQL to execute", vim.log.levels.WARN)
    return
  end

  -- For now, just execute this line
  -- TODO: Expand to full statement
  local buffer_info = UiQuery.query_buffers[bufnr]
  if not buffer_info or not buffer_info.server then
    vim.notify("SSNS: No server associated with this query buffer", vim.log.levels.ERROR)
    return
  end

  local server = buffer_info.server
  local adapter = server:get_adapter()
  local result = adapter:execute(server.connection, sql)

  if not result.success then
    UiQuery.display_error(result.error, sql, bufnr)
    return
  end

  UiQuery.display_results(result, sql)
end

---Display query error with structured information
---@param error table Error object { message, code, lineNumber, procName }
---@param sql string The SQL that was executed
---@param query_bufnr number The query buffer number
function UiQuery.display_error(error, sql, query_bufnr)
  -- Clean up error message - remove ODBC driver prefix
  local clean_message = error.message or "Unknown error"
  -- Pattern: "[Microsoft][ODBC Driver 17 for SQL Server][SQL Server]Actual message"
  local sql_msg = clean_message:match("%[SQL Server%](.+)$")
  if sql_msg then
    clean_message = sql_msg
  end

  -- Show error notification
  local error_msg = clean_message
  if error.code and error.code ~= vim.NIL then
    error_msg = string.format("[SQL Error %s] %s", error.code, clean_message)
  end

  vim.notify(error_msg, vim.log.levels.ERROR)

  -- Highlight error line in query buffer if lineNumber is available
  if error.lineNumber and error.lineNumber ~= vim.NIL and query_bufnr and vim.api.nvim_buf_is_valid(query_bufnr) then
    local line_num = error.lineNumber - 1  -- Convert to 0-based
    line_num = math.min(math.max(0, line_num), vim.api.nvim_buf_line_count(query_bufnr) - 1)  -- Ensure within buffer range
    -- Create namespace for error highlighting
    local ns_id = vim.api.nvim_create_namespace('ssns_sql_error')

    -- Clear previous error highlights
    vim.api.nvim_buf_clear_namespace(query_bufnr, ns_id, 0, -1)

    -- Highlight the error line
    vim.api.nvim_buf_add_highlight(query_bufnr, ns_id, 'ErrorMsg', line_num, 0, -1)

    -- Add virtual text with error message (just the clean message, not the full notification)
    vim.api.nvim_buf_set_extmark(query_bufnr, ns_id, line_num, 0, {
      virt_text = {{" ← " .. clean_message, "ErrorMsg"}},
      virt_text_pos = "eol",
    })

    -- Move cursor to error line
    local win = vim.fn.bufwinid(query_bufnr)
    if win ~= -1 then
      vim.api.nvim_win_set_cursor(win, {line_num, 0})
    end
  end

  -- Display detailed error in results window
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match("SSNS Results") then
        result_buf = buf
        break
      end
    end
  end

  -- Create new buffer if not found
  if not result_buf then
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, "SSNS Results")
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
  end

  -- Format error message for results window
  local lines = {
    "=== SQL ERROR ===",
    "",
    "Message: " .. clean_message,
  }

  if error.code and error.code ~= vim.NIL then
    table.insert(lines, "Error Code: " .. tostring(error.code))
  end

  if error.lineNumber and error.lineNumber ~= vim.NIL then
    table.insert(lines, "Line Number: " .. tostring(error.lineNumber))
  end

  if error.procName and error.procName ~= vim.NIL then
    table.insert(lines, "Procedure: " .. tostring(error.procName))
  end

  table.insert(lines, "")
  table.insert(lines, "=================")

  -- Set lines in buffer
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(result_buf, 'modifiable', false)

  -- Show results window
  local result_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == result_buf then
      result_win = win
      break
    end
  end

  if not result_win then
    vim.cmd('botright split')
    result_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(result_win, result_buf)
    vim.api.nvim_win_set_height(result_win, 10)
  end

  -- Set keymap to close and toggle
  local common = KeymapManager.get_group("common")
  local query_km = KeymapManager.get_group("query")
  vim.api.nvim_buf_set_keymap(result_buf, 'n', common.close or 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(result_buf, 'n', query_km.toggle_results or '<C-r>',
    "<Cmd>lua require('ssns.ui.core.query').toggle_results()<CR>",
    { noremap = true, silent = true, desc = "Toggle results window" })
end

---Display query results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@param sql string The SQL that was executed
---@param execution_time_ms number? Execution time in milliseconds
function UiQuery.display_results(result, sql, execution_time_ms)
  -- Store results for later export and re-display
  UiQuery.last_results = {
    resultSets = result.resultSets,
    sql = sql,
    execution_time_ms = execution_time_ms,
    metadata = result.metadata,
  }

  -- Try to find existing results buffer
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match("SSNS Results") then
        result_buf = buf
        break
      end
    end
  end

  -- Create new buffer if not found
  if not result_buf then
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, "SSNS Results")
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
  end

  -- Format results with styled ContentBuilder
  local builder = UiQuery.format_results_styled(result.resultSets, sql, execution_time_ms, result.metadata)

  -- Create namespace for result highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_results")

  -- Clear any existing highlights in this namespace
  vim.api.nvim_buf_clear_namespace(result_buf, ns_id, 0, -1)

  -- Render styled content to buffer (sets lines and applies highlights)
  builder:render_to_buffer(result_buf, ns_id)

  -- Check if buffer is already visible in a window
  local result_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == result_buf then
      result_win = win
      break
    end
  end

  -- If buffer is not visible, open it in a split
  if not result_win then
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, result_buf)
    result_win = vim.api.nvim_get_current_win()
  else
    -- If already visible, just focus it
    vim.api.nvim_set_current_win(result_win)
  end

  -- Setup keymaps for results buffer
  UiQuery.setup_results_keymaps(result_buf)
end

---Toggle the results window (show if hidden, hide if visible)
function UiQuery.toggle_results()
  -- Find the results buffer
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match("SSNS Results") then
        result_buf = buf
        break
      end
    end
  end

  -- If no results buffer exists, try to recreate from stored results
  if not result_buf then
    if not UiQuery.last_results or not UiQuery.last_results.resultSets then
      vim.notify("SSNS: No results to show", vim.log.levels.INFO)
      return
    end

    -- Recreate the results buffer from stored data
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, "SSNS Results")
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')

    -- Re-format and populate with styled results
    local builder = UiQuery.format_results_styled(
      UiQuery.last_results.resultSets,
      UiQuery.last_results.sql,
      UiQuery.last_results.execution_time_ms,
      UiQuery.last_results.metadata
    )

    -- Create namespace and render styled content
    local ns_id = vim.api.nvim_create_namespace("ssns_results")
    builder:render_to_buffer(result_buf, ns_id)
  end

  -- Check if buffer is visible in a window
  local result_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == result_buf then
      result_win = win
      break
    end
  end

  if result_win then
    -- Results window is visible, close it
    vim.api.nvim_win_close(result_win, false)
  else
    -- Results window is hidden, open it in a split
    vim.cmd('botright split')
    vim.api.nvim_win_set_buf(0, result_buf)
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_height(new_win, 10)

    -- Setup keymaps for results buffer
    UiQuery.setup_results_keymaps(result_buf)
  end
end

---Parse divider format string and generate lines
---@param format string Divider format (e.g., "20#", "10-\n10-", "5-(%row_count% rows)5-", "%fit%=", "%fit_results%-")
---@param metadata table Metadata for variable replacement (row_count, col_count, result_set_num, total_result_sets, run_time, total_time, chunk_number, batch_number, date, time, result_width)
---@return string[] lines Array of divider lines
function UiQuery.parse_divider_format(format, metadata)
  if not format or format == "" then
    return { "" }  -- Default: single blank line
  end

  -- Replace variables with metadata values (except %fit% and %fit_results%)
  local processed = format
  for key, value in pairs(metadata) do
    -- Skip special patterns that need width calculation
    if key ~= "result_width" then
      processed = processed:gsub("%%" .. key .. "%%", tostring(value))
    end
  end

  -- Split by \n for multiple lines
  -- Handle both actual newlines and escaped \n
  local parts = vim.split(processed, "\n", { plain = true })

  -- PASS 1: Generate lines with %fit% and %fit_results% placeholders, track max width
  local lines = {}
  local max_width = 0
  local has_fit_pattern = false
  local has_fit_results_pattern = false

  for _, part in ipairs(parts) do
    local line

    -- Check if this part contains %fit_results% pattern
    if part:match("%%fit_results%%") then
      has_fit_results_pattern = true
      -- Temporarily replace %fit_results% with empty string to calculate the base line
      local temp_part = part:gsub("%%fit_results%%", "")
      line = temp_part
    -- Check if this part contains %fit% pattern
    elseif part:match("%%fit%%") then
      has_fit_pattern = true
      -- Temporarily replace %fit% with empty string to calculate the base line
      local temp_part = part:gsub("%%fit%%", "")
      line = temp_part
    else
      -- Parse repeat patterns like "20#" or "10-"
      -- Pattern: <number><character(s)>
      local count, char = part:match("^(%d+)(.+)$")
      if count and char then
        -- Repeat pattern found
        line = string.rep(char, tonumber(count))
      else
        -- Raw string
        line = part
      end
    end

    table.insert(lines, line)

    -- Track maximum width
    if #line > max_width then
      max_width = #line
    end
  end

  -- PASS 2: If %fit_results% pattern exists, replace with result_width
  if has_fit_results_pattern then
    local result_width = metadata.result_width or 0
    for i, part in ipairs(parts) do
      if part:match("%%fit_results%%") then
        -- Extract character after %fit_results%
        local char = part:match("%%fit_results%%(.)")
        if char then
          -- Replace %fit_results% with the result_width count
          lines[i] = part:gsub("%%fit_results%%", tostring(result_width))

          -- Now parse the repeat pattern
          local count_str, repeat_char = lines[i]:match("^(%d+)(.+)$")
          if count_str and repeat_char then
            lines[i] = string.rep(repeat_char, tonumber(count_str))
          end
        end
      end
    end
  end

  -- PASS 3: If %fit% pattern exists, replace with max_width
  if has_fit_pattern then
    for i, part in ipairs(parts) do
      if part:match("%%fit%%") then
        -- Extract character after %fit%
        local char = part:match("%%fit%%(.)")
        if char then
          -- Replace %fit% with the max_width count
          lines[i] = part:gsub("%%fit%%", tostring(max_width))

          -- Now parse the repeat pattern
          local count_str, repeat_char = lines[i]:match("^(%d+)(.+)$")
          if count_str and repeat_char then
            lines[i] = string.rep(repeat_char, tonumber(count_str))
          end
        end
      end
    end
  end

  return lines
end

---Format query results for display
---@param resultSets table[] Array of Node.js result sets { rows, columns }
---@param sql string The SQL that was executed
---@param execution_time_ms number? Execution time in milliseconds
---@return string[] lines
function UiQuery.format_results(resultSets, sql, execution_time_ms, query_metadata)
  local lines = {}

  -- Get current date/time
  local date_str = os.date("%Y-%m-%d")
  local time_str = os.date("%H:%M:%S")

  -- Validate input
  if type(resultSets) ~= "table" then
    table.insert(lines, tostring(resultSets))
    return lines
  end

  -- Check if empty (no result sets)
  if #resultSets == 0 then
    -- Check if we have rows affected info from metadata (for UPDATE/INSERT/DELETE/CREATE statements)
    if query_metadata and query_metadata.rowsAffected then
      local rows_affected = query_metadata.rowsAffected
      local has_any_affected = false

      -- Show EACH affected count on its own line (like SSMS Messages tab)
      if type(rows_affected) == "table" then
        for _, count in ipairs(rows_affected) do
          if type(count) == "number" then
            if count > 0 then
              local row_word = count == 1 and "row" or "rows"
              table.insert(lines, string.format("(%d %s affected)", count, row_word))
              has_any_affected = true
            else
              -- 0 rows affected (e.g., CREATE/DROP/ALTER or UPDATE with no matches)
              table.insert(lines, "Commands completed successfully.")
            end
            table.insert(lines, "")
          end
        end
      elseif type(rows_affected) == "number" then
        if rows_affected > 0 then
          local row_word = rows_affected == 1 and "row" or "rows"
          table.insert(lines, string.format("(%d %s affected)", rows_affected, row_word))
          has_any_affected = true
        else
          table.insert(lines, "Commands completed successfully.")
        end
        table.insert(lines, "")
      end

      -- Add total execution time at the end
      if query_metadata.total_execution_time_ms then
        local ms = query_metadata.total_execution_time_ms
        if ms < 1000 then
          table.insert(lines, string.format("Total execution time: %.0fms", ms))
        else
          table.insert(lines, string.format("Total execution time: %.2fs", ms / 1000))
        end
      elseif execution_time_ms then
        if execution_time_ms < 1000 then
          table.insert(lines, string.format("Total execution time: %.0fms", execution_time_ms))
        else
          table.insert(lines, string.format("Total execution time: %.2fs", execution_time_ms / 1000))
        end
      end

      return lines
    end

    -- No metadata, just show completion message with timing if available
    table.insert(lines, "Commands completed successfully.")
    if execution_time_ms then
      if execution_time_ms < 1000 then
        table.insert(lines, string.format("Total execution time: %.0fms", execution_time_ms))
      else
        table.insert(lines, string.format("Total execution time: %.2fs", execution_time_ms / 1000))
      end
    end
    table.insert(lines, "")
    return lines
  end

  -- Get config
  local Config = require('ssns.config')
  local ui_config = Config.get_ui()
  local divider_format = ui_config.result_set_divider or ""
  local show_result_set_info = ui_config.show_result_set_info or false

  -- Format total execution time from metadata (if available)
  local total_time = ""
  if query_metadata and query_metadata.total_execution_time_ms then
    local total_ms = query_metadata.total_execution_time_ms
    if total_ms < 1000 then
      total_time = string.format("%.0fms", total_ms)
    else
      total_time = string.format("%.2fs", total_ms / 1000)
    end
  elseif execution_time_ms then
    -- Fallback to execution_time_ms if no metadata
    if execution_time_ms < 1000 then
      total_time = string.format("%.0fms", execution_time_ms)
    else
      total_time = string.format("%.2fs", execution_time_ms / 1000)
    end
  end

  -- Process each result set
  for i, resultSet in ipairs(resultSets) do
    local rows = resultSet.rows or {}
    local row_count = #rows
    local col_count = 0

    -- Count columns from metadata
    if resultSet.columns and type(resultSet.columns) == "table" then
      for _, _ in pairs(resultSet.columns) do
        col_count = col_count + 1
      end
    elseif row_count > 0 then
      -- Fallback: count from first row
      for _, _ in pairs(rows[1]) do
        col_count = col_count + 1
      end
    end

    -- Format this result set FIRST to get its width (needed for %fit_results%)
    local set_lines, result_width = UiQuery.format_single_result_set(rows, resultSet.columns)

    -- Show divider if multiple result sets or configured to show for single
    if #resultSets > 1 or show_result_set_info then
      if i > 1 or show_result_set_info then
        -- Format per-result execution time (from chunk timing)
        local run_time = ""
        if resultSet.chunk_execution_time_ms then
          local ms = resultSet.chunk_execution_time_ms
          if ms < 1000 then
            run_time = string.format("%.0fms", ms)
          else
            run_time = string.format("%.2fs", ms / 1000)
          end
        end

        local metadata = {
          row_count = row_count,
          col_count = col_count,
          result_set_num = i,
          total_result_sets = #resultSets,
          run_time = run_time,               -- Per-result execution time
          total_time = total_time,           -- Total query execution time (all chunks)
          chunk_number = resultSet.chunk_number,
          batch_number = resultSet.batch_number,
          date = date_str,
          time = time_str,
          result_width = result_width,       -- Width of the formatted result table
        }

        -- Add custom divider
        local divider_lines = UiQuery.parse_divider_format(divider_format, metadata)
        for _, divider_line in ipairs(divider_lines) do
          table.insert(lines, divider_line)
        end
      end
    end

    -- Add formatted result set lines
    for _, line in ipairs(set_lines) do
      table.insert(lines, line)
    end
  end

  -- After result sets, show rowsAffected messages for non-SELECT statements
  -- (for mixed queries like SELECT + UPDATE, or batches with both types)
  if query_metadata and query_metadata.rowsAffected then
    local rows_affected = query_metadata.rowsAffected
    local num_result_sets = #resultSets

    -- For mixed queries, skip the first N rowsAffected values that correspond to SELECTs
    -- (SELECTs already show their data in result tables)
    if type(rows_affected) == "table" then
      local has_non_select_messages = false

      -- Show rowsAffected values starting after the result sets
      -- (assuming SELECTs come first and produce both resultSets AND rowsAffected entries)
      for i = num_result_sets + 1, #rows_affected do
        local count = rows_affected[i]
        if type(count) == "number" then
          if not has_non_select_messages then
            table.insert(lines, "")  -- Blank line before first message
            has_non_select_messages = true
          end
          if count > 0 then
            local row_word = count == 1 and "row" or "rows"
            table.insert(lines, string.format("(%d %s affected)", count, row_word))
          else
            table.insert(lines, "Commands completed successfully.")
          end
        end
      end
    elseif type(rows_affected) == "number" and num_result_sets == 0 then
      -- Single value, no result sets - show it
      if rows_affected > 0 then
        table.insert(lines, "")
        local row_word = rows_affected == 1 and "row" or "rows"
        table.insert(lines, string.format("(%d %s affected)", rows_affected, row_word))
      end
    end
  end

  -- Add total execution time at the end
  if query_metadata and query_metadata.total_execution_time_ms then
    local ms = query_metadata.total_execution_time_ms
    table.insert(lines, "")
    if ms < 1000 then
      table.insert(lines, string.format("Total execution time: %.0fms", ms))
    else
      table.insert(lines, string.format("Total execution time: %.2fs", ms / 1000))
    end
  end

  return lines
end

---Format a single result set for display
---@param result_set table Array of row objects
---@param columns_metadata table? Column metadata from Node.js { colName: { index: 0, ... }, ... }
---@return string[] lines Formatted lines
---@return number result_width Width of the formatted result table
function UiQuery.format_single_result_set(result_set, columns_metadata)
  local lines = {}

  -- Get column names from metadata or first row
  local columns = {}
  local has_columns = false

  if columns_metadata and type(columns_metadata) == "table" then
    -- Try to get columns from metadata
    for col_name, col_info in pairs(columns_metadata) do
      if col_name ~= vim.NIL then  -- Skip vim.NIL keys
        table.insert(columns, { name = col_name, index = col_info.index or 0 })
        has_columns = true
      end
    end

    if has_columns then
      -- Sort by index to maintain column order
      table.sort(columns, function(a, b) return a.index < b.index end)

      -- Extract just the names
      local col_names = {}
      for _, col in ipairs(columns) do
        table.insert(col_names, col.name)
      end
      columns = col_names
    end
  end

  if not has_columns and #result_set > 0 then
    -- Fallback: get column names from first row
    local first_row = result_set[1]
    for key, _ in pairs(first_row) do
      table.insert(columns, key)
    end
    table.sort(columns)
    has_columns = true
  end

  if not has_columns then
    -- No rows and no column metadata - driver limitation with 0-row results
    local msg = "(Query returned 0 rows - column information not available from driver)"
    table.insert(lines, msg)
    return lines, #msg
  end

  -- Calculate column widths
  local widths = {}
  for _, col in ipairs(columns) do
    widths[col] = #tostring(col)
  end

  for _, row in ipairs(result_set) do
    for _, col in ipairs(columns) do
      local value = tostring(row[col] or "")
      -- Replace newlines with space for width calculation
      value = value:gsub("\n", " ")
      if #value > widths[col] then
        widths[col] = #value
      end
    end
  end

  -- Build header
  local header_parts = {}
  for _, col in ipairs(columns) do
    local padded = tostring(col) .. string.rep(" ", widths[col] - #tostring(col))
    table.insert(header_parts, padded)
  end
  local header_line = table.concat(header_parts, " | ")
  table.insert(lines, header_line)

  -- Build separator
  local sep_parts = {}
  for _, col in ipairs(columns) do
    table.insert(sep_parts, string.rep("-", widths[col]))
  end
  local separator_line = table.concat(sep_parts, "-+-")
  table.insert(lines, separator_line)

  -- Calculate result width from header (which includes all column widths + separators)
  local result_width = #header_line

  -- Build rows
  if #result_set > 0 then
    for _, row in ipairs(result_set) do
      local row_parts = {}
      for _, col in ipairs(columns) do
        local value = tostring(row[col] or "")
        -- Replace newlines with space for display
        value = value:gsub("\n", " ")
        local padded = value .. string.rep(" ", widths[col] - #value)
        table.insert(row_parts, padded)
      end
      table.insert(lines, table.concat(row_parts, " | "))
    end
  else
    -- No rows returned - show message
    table.insert(lines, "")
    table.insert(lines, "(0 rows)")
  end

  return lines, result_width
end

---Format a single result set with ContentBuilder for styled display
---Supports multi-line cells, row numbers, and row separators (SSMS style)
---@param result_set table Array of row objects
---@param columns_metadata table? Column metadata from Node.js { colName: { index: 0, type: string, ... }, ... }
---@param builder ContentBuilder ContentBuilder instance to add to
---@param results_config table Results display configuration
---@return number result_width Width of the formatted result table
function UiQuery.format_single_result_set_styled(result_set, columns_metadata, builder, results_config)
  local ContentBuilder = require('ssns.ui.core.content_builder')

  -- Extract config values
  local color_mode = results_config.color_mode or "datatype"
  local border_style = results_config.border_style or "box"
  local highlight_null = results_config.highlight_null ~= false
  local null_display = results_config.null_display or "NULL"
  local max_col_width = results_config.max_col_width  -- nil = no limit
  local wrap_mode = results_config.wrap_mode or "word"
  local show_row_numbers = results_config.show_row_numbers ~= false  -- default true
  local preserve_newlines = results_config.preserve_newlines ~= false  -- default true

  -- Get column names and types from metadata or first row
  -- Track both actual key (for row access) and display name (for UI)
  local columns = {}  -- Array of { key = actual_key, display = display_name }
  local column_types = {}
  local has_columns = false

  if columns_metadata and type(columns_metadata) == "table" then
    -- Get columns from metadata
    for col_name, col_info in pairs(columns_metadata) do
      -- Include all columns, even those with nil/empty names
      local actual_key = col_name
      local display_name = col_name

      -- Check if column name is nil, vim.NIL, or empty string
      if col_name == nil or col_name == vim.NIL or col_name == "" then
        display_name = "(No column name)"
        -- The actual_key remains as-is for row access
      end

      table.insert(columns, { key = actual_key, display = display_name, index = col_info.index or 0 })
      column_types[actual_key] = col_info.type or "unknown"
      has_columns = true
    end

    if has_columns then
      -- Sort by index to maintain column order
      table.sort(columns, function(a, b) return a.index < b.index end)
    end
  end

  if not has_columns and #result_set > 0 then
    -- Fallback: get column names from first row
    local first_row = result_set[1]
    for key, _ in pairs(first_row) do
      local display_name = key
      if key == nil or key == vim.NIL or key == "" then
        display_name = "(No column name)"
      end
      table.insert(columns, { key = key, display = display_name })
    end
    -- Sort by display name for fallback case
    table.sort(columns, function(a, b) return tostring(a.display) < tostring(b.display) end)
    has_columns = true
  end

  if not has_columns then
    -- No rows and no column metadata
    builder:styled("(Query returned 0 rows - column information not available from driver)", "muted")
    return 80
  end

  -- Calculate row number column width based on row count
  local row_num_width = nil
  if show_row_numbers then
    local row_count = #result_set
    if row_count == 0 then
      row_num_width = 1  -- Just "#" header
    else
      row_num_width = math.max(1, #tostring(row_count))
    end
  end

  -- Calculate column widths
  -- Start with header display name widths
  local widths = {}
  for i, col in ipairs(columns) do
    widths[i] = #tostring(col.display)
  end

  -- Check all values (considering wrapped lines) to find max width per column
  -- But cap at max_col_width if set
  for _, row in ipairs(result_set) do
    for i, col in ipairs(columns) do
      local value = row[col.key]
      local value_str
      if value == nil or value == vim.NIL then
        value_str = null_display
      else
        value_str = tostring(value)
      end

      -- If no max_col_width, find the longest line in the value
      if not max_col_width then
        -- Split by newlines and find max line length
        local lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
        for _, line in ipairs(lines) do
          if #line > widths[i] then
            widths[i] = #line
          end
        end
      else
        -- Cap at max_col_width
        if widths[i] < max_col_width then
          local lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
          for _, line in ipairs(lines) do
            local line_width = math.min(#line, max_col_width)
            if line_width > widths[i] then
              widths[i] = line_width
            end
          end
        end
      end
    end
  end

  -- Apply max_col_width cap to final widths
  if max_col_width then
    for i, _ in ipairs(columns) do
      if widths[i] > max_col_width then
        widths[i] = max_col_width
      end
    end
  end

  -- Build column info for ContentBuilder (use display name for header)
  local col_info = {}
  for i, col in ipairs(columns) do
    table.insert(col_info, { name = col.display, width = widths[i] })
  end

  -- Calculate result width
  local result_width = 1  -- Starting border
  if row_num_width then
    result_width = result_width + row_num_width + 3  -- row num col + padding + border
  end
  for i, _ in ipairs(columns) do
    result_width = result_width + widths[i] + 3  -- width + 2 padding + 1 border
  end

  -- Build table with borders (using rownum variants)
  builder:result_top_border_with_rownum(col_info, border_style, row_num_width)
  builder:result_header_row_with_rownum(col_info, border_style, row_num_width)
  builder:result_separator_with_rownum(col_info, border_style, row_num_width)

  -- Build data rows with multi-line support and row separators
  if #result_set > 0 then
    for row_idx, row in ipairs(result_set) do
      -- Pre-calculate wrapped lines for each cell in this row
      local cell_lines = {}
      for i, col in ipairs(columns) do
        local value = row[col.key]
        local is_null = (value == nil or value == vim.NIL)
        local value_str
        if is_null then
          value_str = null_display
        else
          value_str = tostring(value)
        end

        -- Wrap the text if max_col_width is set
        local lines
        if max_col_width and widths[i] >= max_col_width then
          lines = ContentBuilder.wrap_text(value_str, widths[i], wrap_mode, preserve_newlines)
        elseif preserve_newlines and value_str:match("[\r\n]") then
          -- Just split by newlines, no wrapping needed
          lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
        else
          lines = { value_str:gsub("[\r\n]", " ") }
        end

        table.insert(cell_lines, {
          lines = lines,
          width = widths[i],
          datatype = column_types[col.key],
          is_null = is_null,
        })
      end

      -- Add row separator before each row (except first)
      if row_idx > 1 then
        builder:result_row_separator_with_rownum(col_info, border_style, row_num_width)
      end

      -- Render the multi-line row
      builder:result_multiline_data_row(cell_lines, color_mode, border_style, highlight_null, row_idx, row_num_width)
    end
  else
    -- No rows - add empty indicator row
    local empty_cells = {}
    for i, _ in ipairs(columns) do
      table.insert(empty_cells, { lines = { "" }, width = widths[i], datatype = nil, is_null = false })
    end
    builder:result_multiline_data_row(empty_cells, "none", border_style, false, nil, row_num_width)
  end

  builder:result_bottom_border_with_rownum(col_info, border_style, row_num_width)

  return result_width
end

---Format all result sets with ContentBuilder for styled display
---@param resultSets table Array of result set objects
---@param sql string? The SQL query (unused but kept for API compatibility)
---@param execution_time_ms number? Execution time in milliseconds
---@param query_metadata table? Query metadata including rowsAffected and timing
---@return ContentBuilder builder ContentBuilder with all styled content
function UiQuery.format_results_styled(resultSets, sql, execution_time_ms, query_metadata)
  local ContentBuilder = require('ssns.ui.core.content_builder')
  local Config = require('ssns.config')
  local results_config = Config.get_results()
  local ui_config = Config.get_ui()

  local builder = ContentBuilder.new()

  -- Validate input
  if type(resultSets) ~= "table" then
    builder:line(tostring(resultSets))
    return builder
  end

  -- Check if empty (no result sets) - show rowsAffected messages
  if #resultSets == 0 then
    if query_metadata and query_metadata.rowsAffected then
      local rows_affected = query_metadata.rowsAffected

      -- Show EACH affected count on its own line
      if type(rows_affected) == "table" then
        for _, count in ipairs(rows_affected) do
          if type(count) == "number" then
            if count > 0 then
              local row_word = count == 1 and "row" or "rows"
              builder:result_message(string.format("(%d %s affected)", count, row_word))
            else
              builder:styled("Commands completed successfully.", "success")
            end
            builder:blank()
          end
        end
      elseif type(rows_affected) == "number" then
        if rows_affected > 0 then
          local row_word = rows_affected == 1 and "row" or "rows"
          builder:result_message(string.format("(%d %s affected)", rows_affected, row_word))
        else
          builder:styled("Commands completed successfully.", "success")
        end
        builder:blank()
      end

      -- Add total execution time
      local ms = query_metadata.total_execution_time_ms or execution_time_ms
      if ms then
        local time_str = ms < 1000 and string.format("%.0fms", ms) or string.format("%.2fs", ms / 1000)
        builder:styled(string.format("Total execution time: %s", time_str), "muted")
      end

      return builder
    end

    -- No metadata, just show completion message
    builder:styled("Commands completed successfully.", "success")
    if execution_time_ms then
      local time_str = execution_time_ms < 1000 and string.format("%.0fms", execution_time_ms) or string.format("%.2fs", execution_time_ms / 1000)
      builder:styled(string.format("Total execution time: %s", time_str), "muted")
    end
    builder:blank()
    return builder
  end

  -- Process each result set
  local divider_format = ui_config.result_set_divider or ""
  local show_result_set_info = ui_config.show_result_set_info or false
  local date_str = os.date("%Y-%m-%d")
  local time_str = os.date("%H:%M:%S")

  -- Format total execution time
  local total_time = ""
  local total_ms = (query_metadata and query_metadata.total_execution_time_ms) or execution_time_ms
  if total_ms then
    total_time = total_ms < 1000 and string.format("%.0fms", total_ms) or string.format("%.2fs", total_ms / 1000)
  end

  for i, resultSet in ipairs(resultSets) do
    local rows = resultSet.rows or {}
    local row_count = #rows
    local col_count = 0

    -- Count columns
    if resultSet.columns and type(resultSet.columns) == "table" then
      for _ in pairs(resultSet.columns) do
        col_count = col_count + 1
      end
    elseif row_count > 0 then
      for _ in pairs(rows[1]) do
        col_count = col_count + 1
      end
    end

    -- Add divider if multiple result sets or configured
    if #resultSets > 1 or show_result_set_info then
      if i > 1 or show_result_set_info then
        -- Format per-result execution time
        local run_time = ""
        if resultSet.chunk_execution_time_ms then
          local ms = resultSet.chunk_execution_time_ms
          run_time = ms < 1000 and string.format("%.0fms", ms) or string.format("%.2fs", ms / 1000)
        end

        -- Parse divider format (reuse existing parser for plain text version)
        if divider_format ~= "" then
          local metadata = {
            row_count = row_count, col_count = col_count,
            result_set_num = i, total_result_sets = #resultSets,
            run_time = run_time, total_time = total_time,
            chunk_number = resultSet.chunk_number, batch_number = resultSet.batch_number,
            date = date_str, time = time_str, result_width = 80,
          }
          local divider_lines = UiQuery.parse_divider_format(divider_format, metadata)
          for _, div_line in ipairs(divider_lines) do
            builder:styled(div_line, "muted")
          end
        end
      end
    end

    -- Add blank line between result sets
    if i > 1 then
      builder:blank()
    end

    -- Format this result set
    UiQuery.format_single_result_set_styled(rows, resultSet.columns, builder, results_config)
  end

  -- After result sets, show rowsAffected for non-SELECT statements
  if query_metadata and query_metadata.rowsAffected then
    local rows_affected = query_metadata.rowsAffected
    local num_result_sets = #resultSets

    if type(rows_affected) == "table" then
      local has_messages = false
      for i = num_result_sets + 1, #rows_affected do
        local count = rows_affected[i]
        if type(count) == "number" then
          if not has_messages then
            builder:blank()
            has_messages = true
          end
          if count > 0 then
            local row_word = count == 1 and "row" or "rows"
            builder:result_message(string.format("(%d %s affected)", count, row_word))
          else
            builder:styled("Commands completed successfully.", "success")
          end
        end
      end
    end
  end

  -- Add total execution time at the end
  if total_ms then
    builder:blank()
    builder:styled(string.format("Total execution time: %s", total_time), "muted")
  end

  return builder
end

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

-- ============================================================================
-- Stored Procedure Parameter Support
-- ============================================================================

---Check if SQL is a stored procedure execution statement
---@param sql string The SQL to check
---@return boolean is_exec Whether it's an EXEC/EXECUTE statement
---@return string? proc_name The procedure name if found
function UiQuery.is_stored_procedure_exec(sql)
  -- Trim whitespace and remove comments
  local trimmed = sql:gsub("^%s+", ""):gsub("%s+$", "")
  trimmed = trimmed:gsub("%-%-[^\n]*\n", "") -- Remove single-line comments
  trimmed = trimmed:gsub("/%*.-%*/", "")    -- Remove multi-line comments
  trimmed = trimmed:gsub("^%s+", "")

  -- Check for EXEC or EXECUTE keyword
  local exec_pattern = "^[Ee][Xx][Ee][Cc]%s+"
  local execute_pattern = "^[Ee][Xx][Ee][Cc][Uu][Tt][Ee]%s+"

  local match_pos = trimmed:match(execute_pattern) or trimmed:match(exec_pattern)
  if not match_pos then
    return false, nil
  end

  -- Extract procedure name (before any parameters or WHERE clause)
  local proc_line = trimmed:match("^[Ee][Xx][Ee][Cc][Uu]?[Tt]?[Ee]?%s+(.+)")
  if not proc_line then
    return false, nil
  end

  -- Get procedure name (stop at space, comma, or semicolon)
  local proc_name = proc_line:match("^([^%s,;@]+)")
  if proc_name then
    -- Remove square brackets if present
    proc_name = proc_name:gsub("%[", ""):gsub("%]", "")
    return true, proc_name
  end

  return false, nil
end

---Parse schema and procedure name
---@param full_name string The full procedure name (e.g., "dbo.MyProc" or "MyProc")
---@return string? schema_name
---@return string proc_name
function UiQuery.parse_procedure_name(full_name)
  local parts = vim.split(full_name, ".", { plain = true })
  if #parts == 2 then
    return parts[1], parts[2]
  elseif #parts == 1 then
    return "dbo", parts[1]  -- Default schema for SQL Server
  end
  return nil, full_name
end

---Prompt for procedure parameters and execute
---@param bufnr number Buffer number
---@param sql string Original SQL
---@param server ServerClass Server instance
---@param database_name string? Database name
function UiQuery.execute_with_params(bufnr, sql, server, database_name)
  local is_exec, proc_name = UiQuery.is_stored_procedure_exec(sql)
  if not is_exec or not proc_name then
    vim.notify("SSNS: Could not parse procedure name from: " .. sql:sub(1, 50), vim.log.levels.ERROR)
    return
  end

  local schema_name, bare_proc_name = UiQuery.parse_procedure_name(proc_name)

  -- Get parameters from database
  local adapter = server:get_adapter()
  local params_query = adapter:get_parameters_query(database_name or "master", schema_name, bare_proc_name, "PROCEDURE")

  vim.notify("SSNS: Fetching procedure parameters...", vim.log.levels.INFO)

  local Connection = require('ssns.connection')
  local params_result = Connection.execute(server.connection_config, params_query)

  if not params_result.success then
    vim.notify("SSNS: Failed to fetch parameters: " .. (params_result.error and params_result.error.message or "Unknown error"),
      vim.log.levels.ERROR)
    return
  end

  local parameters = adapter:parse_parameters(params_result)

  if #parameters == 0 then
    -- No parameters, just execute directly
    UiQuery.execute_query(bufnr, false)
    return
  end

  -- Show parameter input UI
  local UiParamInput = require('ssns.ui.dialogs.param_input')
  UiParamInput.show_input(
    (schema_name and schema_name .. "." or "") .. bare_proc_name,
    server.name,
    database_name,
    parameters,
    function(values)
      -- Build EXEC statement with parameter values
      local exec_statement = UiQuery.build_exec_statement(schema_name, bare_proc_name, parameters, values)

      -- Create temporary buffer with the built statement
      local temp_lines = vim.split(exec_statement, "\n")
      local temp_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, temp_lines)

      -- Execute using the temporary buffer
      local buffer_info = UiQuery.query_buffers[bufnr]
      UiQuery.query_buffers[temp_buf] = buffer_info

      UiQuery.execute_query(temp_buf, false)

      -- Clean up temp buffer
      vim.api.nvim_buf_delete(temp_buf, { force = true })
    end
  )
end

---Build EXEC statement with parameter values
---@param schema_name string? Schema name
---@param proc_name string Procedure name
---@param parameters table[] Parameter definitions
---@param values table<string, string> Parameter values
---@return string exec_statement
function UiQuery.build_exec_statement(schema_name, proc_name, parameters, values)
  local full_name = schema_name and string.format("[%s].[%s]", schema_name, proc_name) or string.format("[%s]", proc_name)
  local param_parts = {}

  for _, param in ipairs(parameters) do
    if param.direction == "IN" or param.direction == "INOUT" then
      local value = values[param.name] or ""

      -- Quote string values, keep numbers as-is
      if value == "" or value:lower() == "null" then
        value = "NULL"
      elseif param.data_type:match("char") or param.data_type:match("date") or param.data_type:match("time") then
        value = "'" .. value:gsub("'", "''") .. "'"  -- Escape single quotes
      end

      table.insert(param_parts, string.format("%s = %s", param.name, value))
    end
  end

  local exec_statement = string.format("EXEC %s %s;", full_name, table.concat(param_parts, ", "))
  return exec_statement
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
-- Results Buffer Keymaps and Export
-- ============================================================================

---Setup keymaps for the results buffer
---@param result_buf number The results buffer number
---Show controls popup for results buffer
function UiQuery.show_results_controls()
  local UiFloat = require('ssns.ui.core.float')
  local km = KeymapManager.get_group("results")
  local query_km = KeymapManager.get_group("query")

  local controls = {
    {
      header = "Results Buffer",
      keys = {
        { key = km.close or "q", desc = "Close results window" },
        { key = km.toggle or query_km.toggle_results or "C-r", desc = "Toggle results window" },
        { key = km.export_csv or "A-e", desc = "Export results to CSV file" },
        { key = km.yank_csv or "A-y", desc = "Yank results as CSV to clipboard" },
      },
    },
  }

  UiFloat._show_controls_popup(controls)
end

function UiQuery.setup_results_keymaps(result_buf)
  local km = KeymapManager.get_group("results")
  local query_km = KeymapManager.get_group("query")

  local keymaps = {
    -- Close results window
    { mode = "n", lhs = km.close or "q", rhs = function()
      vim.cmd('close')
    end, desc = "Close results window" },

    -- Toggle results window
    { mode = "n", lhs = km.toggle or query_km.toggle_results or "<C-r>", rhs = function()
      UiQuery.toggle_results()
    end, desc = "Toggle results window" },

    -- Export to CSV
    { mode = "n", lhs = km.export_csv or "<A-e>", rhs = function()
      UiQuery.export_results_to_csv()
    end, desc = "Export results to CSV" },

    -- Yank as CSV to clipboard
    { mode = "n", lhs = km.yank_csv or "<A-y>", rhs = function()
      UiQuery.yank_results_as_csv()
    end, desc = "Yank results as CSV" },

    -- Show controls
    { mode = "n", lhs = "?", rhs = function()
      UiQuery.show_results_controls()
    end, desc = "Show controls" },
  }

  KeymapManager.set_multiple(result_buf, keymaps, true)
  KeymapManager.mark_group_active(result_buf, "results")
end

---Escape a value for CSV format
---@param value any The value to escape
---@return string escaped The escaped CSV value
local function escape_csv_value(value)
  if value == nil or value == vim.NIL then
    return ""
  end

  local str = tostring(value)

  -- Check if quoting is needed (contains comma, quote, newline, or leading/trailing whitespace)
  if str:match('[,"\n\r]') or str:match("^%s") or str:match("%s$") then
    -- Escape double quotes by doubling them
    str = str:gsub('"', '""')
    -- Wrap in quotes
    str = '"' .. str .. '"'
  end

  return str
end

---Convert result sets to CSV format
---@param resultSets table[] Array of result sets
---@param result_set_index number? Which result set to export (nil = first, 0 = all)
---@return string csv The CSV content
function UiQuery.results_to_csv(resultSets, result_set_index)
  if not resultSets or #resultSets == 0 then
    return ""
  end

  local csv_lines = {}

  -- Determine which result sets to export
  local sets_to_export = {}
  if result_set_index == 0 then
    -- Export all result sets
    sets_to_export = resultSets
  else
    -- Export specific result set (default to first)
    local idx = result_set_index or 1
    if resultSets[idx] then
      sets_to_export = { resultSets[idx] }
    end
  end

  for set_idx, resultSet in ipairs(sets_to_export) do
    local rows = resultSet.rows or {}
    local columns_metadata = resultSet.columns

    -- Get column names in order
    local columns = {}
    local has_columns = false

    if columns_metadata and type(columns_metadata) == "table" then
      for col_name, col_info in pairs(columns_metadata) do
        if col_name ~= vim.NIL then
          table.insert(columns, { name = col_name, index = col_info.index or 0 })
          has_columns = true
        end
      end

      if has_columns then
        table.sort(columns, function(a, b) return a.index < b.index end)
        local col_names = {}
        for _, col in ipairs(columns) do
          table.insert(col_names, col.name)
        end
        columns = col_names
      end
    end

    if not has_columns and #rows > 0 then
      -- Fallback: get column names from first row
      for key, _ in pairs(rows[1]) do
        table.insert(columns, key)
      end
      table.sort(columns)
      has_columns = true
    end

    if not has_columns then
      goto continue
    end

    -- Add separator comment for multiple result sets
    if #sets_to_export > 1 and set_idx > 1 then
      table.insert(csv_lines, "")
      table.insert(csv_lines, string.format("# Result Set %d", set_idx))
    end

    -- Add header row
    local header_parts = {}
    for _, col in ipairs(columns) do
      table.insert(header_parts, escape_csv_value(col))
    end
    table.insert(csv_lines, table.concat(header_parts, ","))

    -- Add data rows
    for _, row in ipairs(rows) do
      local row_parts = {}
      for _, col in ipairs(columns) do
        table.insert(row_parts, escape_csv_value(row[col]))
      end
      table.insert(csv_lines, table.concat(row_parts, ","))
    end

    ::continue::
  end

  return table.concat(csv_lines, "\n")
end

---Open a file with the system default application
---@param filepath string The file path to open
local function open_with_default_app(filepath)
  local cmd
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    -- Windows: use start command
    cmd = { "cmd", "/c", "start", "", filepath }
  elseif vim.fn.has("mac") == 1 then
    -- macOS: use open command
    cmd = { "open", filepath }
  else
    -- Linux/Unix: use xdg-open
    cmd = { "xdg-open", filepath }
  end

  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format("SSNS: Failed to open %s", filepath), vim.log.levels.WARN)
        end)
      end
    end,
  })
end

---Get the system temp directory
---@return string temp_dir The temp directory path
local function get_temp_dir()
  -- Try common environment variables
  local temp = os.getenv("TEMP")      -- Windows
    or os.getenv("TMP")               -- Windows alternative
    or os.getenv("TMPDIR")            -- macOS
    or "/tmp"                         -- Linux/Unix fallback

  return temp
end

---Export results to CSV file and open in default application
---@param filepath string? Optional file path (uses config export_directory if not provided)
function UiQuery.export_results_to_csv(filepath)
  if not UiQuery.last_results or not UiQuery.last_results.resultSets then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  local csv_content = UiQuery.results_to_csv(UiQuery.last_results.resultSets, 0)
  if csv_content == "" then
    vim.notify("SSNS: No data to export", vim.log.levels.WARN)
    return
  end

  -- Generate filename with timestamp
  local filename = os.date("ssns_results_%Y%m%d_%H%M%S.csv")

  if not filepath then
    local Config = require('ssns.config')
    local query_config = Config.get_query()
    local export_dir = query_config.export_directory

    if export_dir == "" then
      -- Empty string means prompt for location
      filepath = vim.fn.input({
        prompt = "Export CSV to: ",
        default = filename,
        completion = "file",
      })

      if filepath == "" then
        vim.notify("SSNS: Export cancelled", vim.log.levels.INFO)
        return
      end

      filepath = vim.fn.expand(filepath)
    else
      -- Use configured directory or fall back to temp
      local dir = export_dir or get_temp_dir()
      dir = vim.fn.expand(dir)  -- Handle ~ and env vars

      -- Ensure directory exists
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end

      filepath = dir .. "/" .. filename

      -- Normalize path separators for Windows
      if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        filepath = filepath:gsub("/", "\\")
      end
    end
  else
    -- Expand provided path (handle ~, etc.)
    filepath = vim.fn.expand(filepath)
  end

  -- Write to file
  local file, err = io.open(filepath, "w")
  if not file then
    vim.notify(string.format("SSNS: Failed to write file: %s", err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  file:write(csv_content)
  file:close()

  vim.notify(string.format("SSNS: Results exported to %s", filepath), vim.log.levels.INFO)

  -- Open in default application
  open_with_default_app(filepath)
end

---Yank results as CSV to clipboard
function UiQuery.yank_results_as_csv()
  if not UiQuery.last_results or not UiQuery.last_results.resultSets then
    vim.notify("SSNS: No results to copy", vim.log.levels.WARN)
    return
  end

  local csv_content = UiQuery.results_to_csv(UiQuery.last_results.resultSets, 0)
  if csv_content == "" then
    vim.notify("SSNS: No data to copy", vim.log.levels.WARN)
    return
  end

  -- Copy to clipboard
  vim.fn.setreg("+", csv_content)
  vim.fn.setreg("*", csv_content)

  -- Count rows for feedback
  local row_count = 0
  for _, resultSet in ipairs(UiQuery.last_results.resultSets) do
    if resultSet.rows then
      row_count = row_count + #resultSet.rows
    end
  end

  vim.notify(string.format("SSNS: Copied %d rows as CSV to clipboard", row_count), vim.log.levels.INFO)
end

---Get the last results (for external access)
---@return table? last_results The stored results or nil
function UiQuery.get_last_results()
  return UiQuery.last_results
end

---Clear stored results
function UiQuery.clear_last_results()
  UiQuery.last_results = nil
end

return UiQuery
