---@class EtlExecutor
---Executes ETL scripts sequentially with proper connection handling
---@field context EtlContext Execution context
---@field script EtlScript Parsed script
---@field progress_callback fun(event: EtlProgressEvent)? UI progress callback
---@field cancelled boolean Whether execution was cancelled
---@field current_server string? Currently active server name
---@field current_database string? Currently active database name
local EtlExecutor = {}
EtlExecutor.__index = EtlExecutor

local EtlContext = require("nvim-ssns.etl.context")
local Cache = require("nvim-ssns.cache")
local Connection = require("nvim-ssns.connection")
local Transfer = require("nvim-ssns.etl.transfer")
local Macros = require("nvim-ssns.etl.macros")

---@class EtlProgressEvent
---@field type "start"|"block_start"|"block_complete"|"block_error"|"complete"|"cancelled"
---@field script EtlScript? Script being executed (for "start")
---@field block EtlBlock? Current block (for block events)
---@field block_index number? Current block index (1-based)
---@field total_blocks number? Total blocks in script
---@field result EtlResult? Block result (for "block_complete")
---@field error EtlBlockError? Block error (for "block_error")
---@field summary EtlExecutionSummary? Final summary (for "complete")

---@class EtlExecuteOptions
---@field server string? Default server name if not specified in blocks
---@field database string? Default database if not specified in blocks
---@field variables table<string, any>? Additional variables to merge
---@field dry_run boolean? If true, validate but don't execute
---@field progress_callback fun(event: EtlProgressEvent)? Progress callback
---@field bufnr number? Buffer number for history recording
---@field record_history boolean? Whether to record to history (default: true)

---Create a new executor
---@param script EtlScript Parsed and validated script
---@param opts EtlExecuteOptions? Options
---@return EtlExecutor
function EtlExecutor.new(script, opts)
  opts = opts or {}

  local self = setmetatable({}, EtlExecutor)

  self.script = script
  self.context = EtlContext.new(script)
  self.progress_callback = opts.progress_callback
  self.cancelled = false
  self.current_server = opts.server
  self.current_database = opts.database
  self.bufnr = opts.bufnr
  self.record_history = opts.record_history ~= false -- Default true

  -- Merge additional variables
  if opts.variables then
    for name, value in pairs(opts.variables) do
      self.context:set_variable(name, value)
    end
  end

  return self
end

---Report progress to callback
---@param event EtlProgressEvent
function EtlExecutor:_report_progress(event)
  if self.progress_callback then
    -- Use vim.schedule to ensure UI updates happen safely
    vim.schedule(function()
      self.progress_callback(event)
    end)
  end
end

---Resolve server for a block
---@param block EtlBlock
---@return ServerClass? server, string? error
function EtlExecutor:_resolve_server(block)
  local server_name = block.server or self.current_server

  if not server_name then
    return nil, string.format("Block '%s' has no server specified and no default server", block.name)
  end

  local server = Cache.servers_by_name[server_name]
  if not server then
    return nil, string.format("Server '%s' not found for block '%s'", server_name, block.name)
  end

  return server, nil
end

---Resolve database for a block
---@param block EtlBlock
---@param server ServerClass
---@return string? database
function EtlExecutor:_resolve_database(block, server)
  -- Priority: block directive > inherited > server default
  return block.database or self.current_database or server.current_database
end

---Substitute @input placeholder in SQL
---@param sql string SQL with potential @input placeholder
---@param block EtlBlock Block being executed
---@param target_server ServerClass Target server for this block
---@param target_connection_config table Connection config for target
---@return string sql Modified SQL
---@return string? error Error if input resolution fails
function EtlExecutor:_substitute_input(sql, block, target_server, target_connection_config)
  if not block.input then
    return sql, nil
  end

  -- Check if input block result exists
  local input_result = self.context:get_result(block.input)
  if not input_result then
    return sql, string.format("Input block '%s' has no result", block.input)
  end

  local rows = input_result.rows
  if not rows or #rows == 0 then
    -- Empty input - check skip_on_empty option
    if block.options.skip_on_empty then
      return "", nil -- Signal to skip
    end
    -- Replace @input with empty subquery
    return sql:gsub("@input", "(SELECT TOP 0 * FROM (SELECT 1 as _empty) t WHERE 1=0)"), nil
  end

  -- Find the source block to determine its server
  local source_block = nil
  for _, b in ipairs(self.script.blocks) do
    if b.name == block.input then
      source_block = b
      break
    end
  end

  local source_server_name = source_block and source_block.server or self.current_server
  local target_server_name = target_server.name

  -- Check if cross-server transfer is needed
  local needs_transfer = Transfer.needs_transfer(source_server_name or "", target_server_name or "")

  -- For small same-server datasets, use inline VALUES (faster)
  if not needs_transfer and #rows <= 100 then
    local values_sql = EtlExecutor._create_values_clause(rows, input_result.columns)
    if values_sql then
      return sql:gsub("@input", "(" .. values_sql .. ")"), nil
    end
  end

  -- For large datasets or cross-server transfers, use temp tables
  local db_type = target_server.connection_config and target_server.connection_config.type or "sqlserver"

  local transfer_result = Transfer.prepare_input(
    self.context,
    block.input,
    target_connection_config,
    db_type,
    {
      source_server = source_server_name,
      target_server = target_server_name,
    }
  )

  if not transfer_result.success then
    return sql, transfer_result.error
  end

  -- Replace @input with temp table name
  local placeholder = Transfer.get_input_placeholder(transfer_result.temp_table_name, db_type)
  return sql:gsub("@input", placeholder), nil
end

---Create a VALUES clause from rows (for small datasets)
---@param rows table[]
---@param columns table<string, ColumnMeta>
---@return string? values_sql
function EtlExecutor._create_values_clause(rows, columns)
  if #rows == 0 then
    return nil
  end

  -- Get column order from first row
  local col_names = {}
  for col_name, _ in pairs(rows[1]) do
    table.insert(col_names, col_name)
  end
  table.sort(col_names) -- Consistent order

  -- Build SELECT ... UNION ALL ... pattern (more compatible than VALUES)
  local selects = {}
  for _, row in ipairs(rows) do
    local values = {}
    for _, col_name in ipairs(col_names) do
      local val = row[col_name]
      if val == nil then
        table.insert(values, "NULL")
      elseif type(val) == "string" then
        -- Escape single quotes
        table.insert(values, "'" .. val:gsub("'", "''") .. "'")
      elseif type(val) == "boolean" then
        table.insert(values, val and "1" or "0")
      else
        table.insert(values, tostring(val))
      end
    end
    table.insert(selects, "SELECT " .. table.concat(values, ", "))
  end

  -- Add column aliases to first SELECT
  local first_select_parts = {}
  for i, col_name in ipairs(col_names) do
    local val = rows[1][col_name]
    local val_str
    if val == nil then
      val_str = "NULL"
    elseif type(val) == "string" then
      val_str = "'" .. val:gsub("'", "''") .. "'"
    elseif type(val) == "boolean" then
      val_str = val and "1" or "0"
    else
      val_str = tostring(val)
    end
    table.insert(first_select_parts, val_str .. " AS [" .. col_name .. "]")
  end
  selects[1] = "SELECT " .. table.concat(first_select_parts, ", ")

  return table.concat(selects, " UNION ALL ")
end

---Execute a SQL block
---@param block EtlBlock
---@return EtlResult? result, EtlBlockError? error
function EtlExecutor:_execute_sql_block(block)
  -- Resolve server
  local server, err = self:_resolve_server(block)
  if not server then
    return nil, { message = err }
  end

  -- Resolve database
  local database = self:_resolve_database(block, server)

  -- Update current server/database for inheritance
  self.current_server = server.name
  if database then
    self.current_database = database
  end

  -- Get connection config
  local connection_config = server.connection_config
  if database then
    local Connections = require("nvim-ssns.connections")
    connection_config = Connections.with_database(connection_config, database)
  end

  -- Substitute @input if present
  local sql = block.content
  sql, err = self:_substitute_input(sql, block, server, connection_config)
  if err then
    return nil, { message = err }
  end

  -- Check for skip signal (empty string from skip_on_empty)
  if sql == "" then
    return {
      rows = {},
      columns = {},
      row_count = 0,
      execution_time_ms = 0,
      block_name = block.name,
      block_type = "sql",
      output_type = "sql",
    }, nil
  end

  -- Execute query
  local start_time = vim.loop.hrtime()
  local result = Connection.execute(connection_config, sql, { use_cache = false })
  local execution_time_ms = (vim.loop.hrtime() - start_time) / 1000000

  if not result.success then
    return nil, {
      message = result.error and result.error.message or "Query execution failed",
      line = result.error and result.error.lineNumber,
      sql = sql,
    }
  end

  -- Convert to EtlResult
  return EtlContext.result_from_node(result, block.name, "sql", execution_time_ms, nil), nil
end

---Execute a Lua block
---@param block EtlBlock
---@return EtlResult? result, EtlBlockError? error
function EtlExecutor:_execute_lua_block(block)
  local start_time = vim.loop.hrtime()

  -- Create execution environment (full Lua access + ETL helpers)
  local env = self:_create_environment(block)

  -- Compile the Lua code
  local chunk, compile_err = loadstring(block.content, block.name)
  if not chunk then
    return nil, {
      message = "Lua compile error: " .. tostring(compile_err),
      stack = compile_err,
    }
  end

  -- Set execution environment
  setfenv(chunk, env)

  -- Execute
  local ok, result_or_err = pcall(chunk)
  local execution_time_ms = (vim.loop.hrtime() - start_time) / 1000000

  if not ok then
    return nil, {
      message = "Lua runtime error: " .. tostring(result_or_err),
      stack = debug.traceback(result_or_err, 2),
    }
  end

  -- Handle return value
  local return_value = result_or_err

  -- Check if it's a sql() return
  if type(return_value) == "table" and return_value._etl_type == "sql" then
    local generated_sql = return_value.sql

    -- Now execute the generated SQL
    local server, err = self:_resolve_server(block)
    if not server then
      return nil, { message = err }
    end

    local database = self:_resolve_database(block, server)
    local connection_config = server.connection_config
    if database then
      local Connections = require("nvim-ssns.connections")
      connection_config = Connections.with_database(connection_config, database)
    end

    local sql_start = vim.loop.hrtime()
    local sql_result = Connection.execute(connection_config, generated_sql, { use_cache = false })
    local sql_time = (vim.loop.hrtime() - sql_start) / 1000000

    if not sql_result.success then
      return nil, {
        message = sql_result.error and sql_result.error.message or "Generated SQL execution failed",
        line = sql_result.error and sql_result.error.lineNumber,
        sql = generated_sql,
      }
    end

    local etl_result = EtlContext.result_from_node(
      sql_result,
      block.name,
      "lua",
      execution_time_ms + sql_time,
      generated_sql
    )
    return etl_result, nil
  end

  -- Check if it's a data() return
  if type(return_value) == "table" and return_value._etl_type == "data" then
    return EtlContext.result_from_data(return_value.data, block.name, execution_time_ms), nil
  end

  -- If nil, block produces no output (valid for side-effect blocks)
  if return_value == nil then
    return {
      rows = {},
      columns = {},
      row_count = 0,
      execution_time_ms = execution_time_ms,
      block_name = block.name,
      block_type = "lua",
      output_type = "data",
    }, nil
  end

  -- Unknown return type
  return nil, {
    message = "Lua block must return sql(...), data(...), or nil. Got: " .. type(return_value),
  }
end

---Create execution environment for Lua block
---Full Lua access with ETL helpers taking precedence
---@param block EtlBlock
---@return table env
function EtlExecutor:_create_environment(block)
  local ctx = self.context
  local log_output = {}

  -- ETL-specific helpers
  local etl_env = {
    -- Core ETL functions
    sql = function(query_str)
      if type(query_str) ~= "string" then
        error("sql() requires a string argument", 2)
      end
      return { _etl_type = "sql", sql = query_str }
    end,

    data = function(tbl)
      if type(tbl) ~= "table" then
        error("data() requires a table argument", 2)
      end
      return { _etl_type = "data", data = tbl }
    end,

    ref = function(block_name)
      return ctx:get_result(block_name)
    end,

    var = function(name, default)
      return ctx:get_variable(name, default)
    end,

    -- Results access (read-only proxy)
    results = ctx:create_results_proxy(),

    -- Variables access (read-write proxy)
    vars = ctx:create_vars_proxy(),

    -- Global macro library
    macros = Macros.get_all(),

    -- Redirect print to log
    print = function(...)
      local args = { ... }
      local parts = {}
      for _, arg in ipairs(args) do
        table.insert(parts, tostring(arg))
      end
      table.insert(log_output, table.concat(parts, "\t"))
    end,

    -- Block info
    _block_name = block.name,
    _log = log_output,
  }

  -- Full Lua access with ETL helpers taking precedence
  return setmetatable(etl_env, { __index = _G })
end

---Execute all blocks sequentially
---@return EtlExecutionSummary summary
function EtlExecutor:execute()
  self.context:start()

  -- Report start
  self:_report_progress({
    type = "start",
    script = self.script,
    total_blocks = #self.script.blocks,
  })

  local blocks = self.script.blocks

  for i, block in ipairs(blocks) do
    -- Check for cancellation
    if self.cancelled then
      self.context:cancel()
      self:_report_progress({
        type = "cancelled",
        block = block,
        block_index = i,
        total_blocks = #blocks,
      })
      break
    end

    -- Report block start
    self.context:set_current_block(block.name)
    self:_report_progress({
      type = "block_start",
      block = block,
      block_index = i,
      total_blocks = #blocks,
    })

    -- Execute block
    local result, err
    local block_start = vim.loop.hrtime()

    if block.type == "sql" then
      result, err = self:_execute_sql_block(block)
    else
      result, err = self:_execute_lua_block(block)
    end

    local block_time = (vim.loop.hrtime() - block_start) / 1000000
    self.context:set_block_timing(block.name, block_time)

    if err then
      -- Block failed
      self.context:set_error(block.name, err)

      self:_report_progress({
        type = "block_error",
        block = block,
        block_index = i,
        total_blocks = #blocks,
        error = err,
      })

      -- Check if we should continue
      if not block.options.continue_on_error then
        -- Stop execution
        self.context:finish(false)
        break
      end
    else
      -- Block succeeded
      self.context:set_result(block.name, result)

      self:_report_progress({
        type = "block_complete",
        block = block,
        block_index = i,
        total_blocks = #blocks,
        result = result,
      })
    end
  end

  -- Cleanup temp tables created for cross-server transfers
  local cleaned, cleanup_errors = Transfer.cleanup(self.context)
  if #cleanup_errors > 0 then
    -- Log cleanup errors but don't fail the execution
    for _, err in ipairs(cleanup_errors) do
      vim.schedule(function()
        vim.notify("ETL cleanup warning: " .. err, vim.log.levels.WARN)
      end)
    end
  end

  -- Finalize
  if self.context.status == "running" then
    local has_errors = self.context:has_any_error()
    self.context:finish(not has_errors)
  end

  local summary = self.context:get_summary()

  self:_report_progress({
    type = "complete",
    summary = summary,
  })

  return summary
end

---Execute all blocks asynchronously with vim.schedule between blocks
---This allows the event loop to process UI updates (spinner, progress) between blocks
---@param on_complete fun(summary: EtlExecutionSummary) Callback when execution finishes
function EtlExecutor:execute_async(on_complete)
  self.context:start()

  -- Report start (direct call, not vim.schedule - we're already in the event loop)
  if self.progress_callback then
    self.progress_callback({
      type = "start",
      script = self.script,
      total_blocks = #self.script.blocks,
    })
  end

  local blocks = self.script.blocks
  local executor = self

  -- Process blocks one at a time, yielding to event loop between each
  local function process_block(i)
    -- Check for cancellation
    if executor.cancelled then
      executor.context:cancel()
      if executor.progress_callback then
        executor.progress_callback({
          type = "cancelled",
          block = blocks[i],
          block_index = i,
          total_blocks = #blocks,
        })
      end
      executor:_finalize(on_complete)
      return
    end

    -- All blocks done
    if i > #blocks then
      executor:_finalize(on_complete)
      return
    end

    local block = blocks[i]

    -- Report block start (direct call)
    executor.context:set_current_block(block.name)
    if executor.progress_callback then
      executor.progress_callback({
        type = "block_start",
        block = block,
        block_index = i,
        total_blocks = #blocks,
      })
    end

    -- Defer the actual execution to allow UI to render the "block_start" update
    vim.schedule(function()
      -- Execute block
      local result, err
      local block_start = vim.loop.hrtime()

      if block.type == "sql" then
        result, err = executor:_execute_sql_block(block)
      else
        result, err = executor:_execute_lua_block(block)
      end

      local block_time = (vim.loop.hrtime() - block_start) / 1000000
      executor.context:set_block_timing(block.name, block_time)

      if err then
        -- Block failed
        executor.context:set_error(block.name, err)

        if executor.progress_callback then
          executor.progress_callback({
            type = "block_error",
            block = block,
            block_index = i,
            total_blocks = #blocks,
            error = err,
          })
        end

        -- Check if we should continue
        if not block.options.continue_on_error then
          executor.context:finish(false)
          executor:_finalize(on_complete)
          return
        end
      else
        -- Block succeeded
        executor.context:set_result(block.name, result)

        if executor.progress_callback then
          executor.progress_callback({
            type = "block_complete",
            block = block,
            block_index = i,
            total_blocks = #blocks,
            result = result,
          })
        end
      end

      -- Schedule next block (yields to event loop for UI updates)
      vim.schedule(function()
        process_block(i + 1)
      end)
    end)
  end

  -- Start processing from block 1
  process_block(1)
end

---Finalize execution and call completion callback
---@param on_complete fun(summary: EtlExecutionSummary)?
function EtlExecutor:_finalize(on_complete)
  -- Cleanup temp tables created for cross-server transfers
  local _, cleanup_errors = Transfer.cleanup(self.context)
  if #cleanup_errors > 0 then
    for _, err in ipairs(cleanup_errors) do
      vim.schedule(function()
        vim.notify("ETL cleanup warning: " .. err, vim.log.levels.WARN)
      end)
    end
  end

  -- Finalize
  if self.context.status == "running" then
    local has_errors = self.context:has_any_error()
    self.context:finish(not has_errors)
  end

  local summary = self.context:get_summary()

  if self.progress_callback then
    self.progress_callback({
      type = "complete",
      summary = summary,
    })
  end

  if on_complete then
    on_complete(summary)
  end
end

---Cancel execution
function EtlExecutor:cancel()
  self.cancelled = true
end

---Get the execution context
---@return EtlContext
function EtlExecutor:get_context()
  return self.context
end

---Execute an ETL script (convenience function)
---@param script EtlScript Parsed script
---@param opts EtlExecuteOptions? Options
---@return EtlExecutionSummary summary
---@return EtlContext context
function EtlExecutor.run(script, opts)
  opts = opts or {}
  local executor = EtlExecutor.new(script, opts)
  local summary = executor:execute()
  local context = executor:get_context()

  -- Record to history if enabled
  if executor.record_history and executor.bufnr then
    local ok, EtlHistory = pcall(require, "ssns.history.etl_metadata")
    if ok then
      EtlHistory.add_to_history(executor.bufnr, script, context, summary)
    end
  end

  return summary, context
end

return EtlExecutor
