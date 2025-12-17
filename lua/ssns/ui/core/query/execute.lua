---@class QueryExecute
---Query execution functionality
local QueryExecute = {}

local QueryHistory = require('ssns.query_history')
local KeymapManager = require('ssns.keymap_manager')

---Reference to parent UiQuery module (set during init)
---@type UiQuery
local UiQuery

---Reference to results module
---@type QueryResults
local QueryResults

---Active async tasks for query buffers (for cancellation)
---@type table<number, string> bufnr -> task_id
local active_query_tasks = {}

---Get or create a results buffer for a query buffer
---@param query_bufnr number Query buffer number
---@return number results_bufnr Results buffer number
---@return boolean is_new Whether the buffer was newly created
local function get_or_create_results_buffer(query_bufnr)
  -- Generate unique results buffer name based on query buffer
  local query_buf_name = vim.api.nvim_buf_get_name(query_bufnr)
  local short_name = query_buf_name:match("%[([^%]]+)%]") or tostring(query_bufnr)
  local results_buf_name = string.format("SSNS Results [%s]", short_name)

  -- Try to find existing results buffer
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name == results_buf_name then
        return buf, false
      end
    end
  end

  -- Create new buffer
  local result_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(result_buf, results_buf_name)
  vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(result_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(result_buf, 'bufhidden', 'hide')
  -- Store association: results buffer -> query buffer
  vim.api.nvim_buf_set_var(result_buf, 'ssns_query_bufnr', query_bufnr)

  return result_buf, true
end

---Show results window for a buffer
---@param result_buf number Results buffer number
---@return number win_id Window ID
local function show_results_window(result_buf)
  -- Check if window already exists for this buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == result_buf then
      return win
    end
  end

  -- Create new split window
  vim.cmd('botright split')
  local result_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(result_win, result_buf)
  vim.api.nvim_win_set_height(result_win, 12)

  return result_win
end

---Cancel any running query for a buffer
---@param bufnr number Query buffer number
---@return boolean cancelled True if a query was cancelled
function QueryExecute.cancel_query(bufnr)
  local task_id = active_query_tasks[bufnr]
  if task_id then
    local Async = require('ssns.async')
    local cancelled = Async.cancel(task_id, "Query cancelled by user")
    if cancelled then
      active_query_tasks[bufnr] = nil
      vim.notify("SSNS: Query cancelled", vim.log.levels.INFO)
    end
    return cancelled
  end
  return false
end

---Check if a query is running for a buffer
---@param bufnr number Query buffer number
---@return boolean is_running
function QueryExecute.is_query_running(bufnr)
  return active_query_tasks[bufnr] ~= nil
end

---Execute query in buffer (async with spinner)
---@param bufnr number The buffer number
---@param visual boolean Whether to execute visual selection
function QueryExecute.execute_query(bufnr, visual)
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

  -- Cancel any existing query for this buffer
  if active_query_tasks[bufnr] then
    QueryExecute.cancel_query(bufnr)
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
    sql = table.concat(lines, "\n")
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

  -- Get buffer's current database context
  -- Priority: last_database > database.db_name > nil
  local buffer_db = buffer_info.last_database
  if not buffer_db and buffer_info.database then
    buffer_db = buffer_info.database.db_name
  end

  -- Get or create results buffer and show it immediately
  local results_bufnr, _ = get_or_create_results_buffer(bufnr)
  show_results_window(results_bufnr)

  -- Make results buffer modifiable for spinner
  vim.api.nvim_buf_set_option(results_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {""})

  -- Capture start time for tracking
  local start_time = vim.loop.hrtime()

  -- Execute async with spinner in results buffer
  local Connection = require('ssns.connection')
  local Async = require('ssns.async')

  local task_id = Connection.execute_with_buffer_context_async(
    server.connection_config,
    sql,
    buffer_db,
    {
      bufnr = results_bufnr,
      spinner_text = "Executing query...",
      show_runtime = true,
      line = 0,
      timeout_ms = 300000, -- 5 minutes for long queries
      on_complete = function(result, last_database, err)
        -- Clear task tracking
        active_query_tasks[bufnr] = nil

        local end_time = vim.loop.hrtime()
        local execution_time_ms = (end_time - start_time) / 1000000

        -- Handle cancellation
        if err and (err:match("cancelled") or err:match("Operation cancelled")) then
          QueryResults.show_cancelled(results_bufnr, execution_time_ms)
          return
        end

        -- Handle other errors
        if err then
          vim.notify("SSNS: Query error: " .. tostring(err), vim.log.levels.ERROR)
          return
        end

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
          buffer_name = vim.fn.fnamemodify(buffer_name, ':t')
        end

        local current_database = buffer_info.last_database
          or (buffer_info.database and buffer_info.database.db_name)
          or "master"

        -- Check if query succeeded
        if not result or not result.success then
          -- Track error in history
          local error_obj = result and result.error or { message = "Unknown error" }
          QueryHistory.add_entry(bufnr, buffer_name, {
            query = sql,
            server_name = server.name,
            database = current_database,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            execution_time_ms = execution_time_ms,
            status = "error",
            error_message = error_obj.message or "Unknown error",
            error_line = error_obj.lineNumber,
          })

          -- Display detailed error with structured information
          QueryExecute.display_error(error_obj, sql, bufnr)
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
          local success_usage, err_usage = pcall(function()
            local UsageAnalyzer = require('ssns.completion.usage_analyzer')
            UsageAnalyzer.analyze_and_record(sql, {
              connection_config = server.connection_config
            })
          end)

          if not success_usage then
            local Debug = require('ssns.debug')
            Debug.log("[USAGE] Query analysis error: " .. tostring(err_usage))
          end
        end

        -- Display results with execution metadata (pass pre-created results buffer)
        QueryResults.display_results(result, sql, execution_time_ms, bufnr, results_bufnr)
      end,
    }
  )

  -- Track the task for potential cancellation
  active_query_tasks[bufnr] = task_id
end

---Execute statement under cursor
---@param bufnr number The buffer number
function QueryExecute.execute_statement_under_cursor(bufnr)
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
    QueryExecute.display_error(result.error, sql, bufnr)
    return
  end

  QueryResults.display_results(result, sql, nil, bufnr)
end

---Display query error with structured information
---@param error table Error object { message, code, lineNumber, procName }
---@param sql string The SQL that was executed
---@param query_bufnr number The query buffer number
function QueryExecute.display_error(error, sql, query_bufnr)
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
      virt_text = {{" <- " .. clean_message, "ErrorMsg"}},
      virt_text_pos = "eol",
    })

    -- Move cursor to error line
    local win = vim.fn.bufwinid(query_bufnr)
    if win ~= -1 then
      vim.api.nvim_win_set_cursor(win, {line_num + 1, 0})
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

---Initialize the execute module with parent and sibling references
---@param parent UiQuery The parent UiQuery module
---@param results QueryResults The results module
function QueryExecute._init(parent, results)
  UiQuery = parent
  QueryResults = results
end

return QueryExecute
