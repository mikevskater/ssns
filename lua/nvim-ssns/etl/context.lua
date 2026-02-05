---@class EtlContext
---Manages execution state and result passing for ETL scripts
---@field results table<string, EtlResult> Block name -> result mapping
---@field variables table<string, any> User-defined variables (mutable during execution)
---@field current_block string? Currently executing block name
---@field start_time number Execution start timestamp (os.clock())
---@field errors table<string, EtlBlockError> Block name -> error mapping
---@field status EtlStatus Overall execution status
---@field script EtlScript? Reference to the parsed script
---@field block_timings table<string, number> Block name -> execution time in ms
---@field temp_tables table<string, TempTableInfo> Temp tables created for cross-server transfers
local EtlContext = {}
EtlContext.__index = EtlContext

---@alias EtlStatus "pending"|"running"|"success"|"error"|"cancelled"

---@class EtlResult
---@field rows table[] Array of row objects
---@field columns table<string, ColumnMeta> Column name -> metadata mapping
---@field row_count number Number of rows
---@field rows_affected number? Number of rows affected (for INSERT/UPDATE/DELETE)
---@field execution_time_ms number Block execution time
---@field block_name string Source block name
---@field block_type "sql"|"lua" Source block type
---@field generated_sql string? For Lua blocks, the SQL that was generated
---@field output_type "sql"|"data" Whether result came from SQL execution or data() return

---@class ColumnMeta
---@field name string Column name
---@field type string? SQL type
---@field index number Column index (1-based)

---@class EtlBlockError
---@field message string Error message
---@field line number? Line number in block where error occurred
---@field sql string? SQL that caused the error (for SQL blocks)
---@field stack string? Lua stack trace (for Lua blocks)

---@class TempTableInfo
---@field name string Temp table name (e.g., #ssns_input_source)
---@field server string Server where temp table was created
---@field source_block string Block whose data is in the temp table
---@field columns table<string, ColumnMeta> Column definitions
---@field row_count number Rows inserted
---@field connection_config table Connection config for cleanup
---@field db_type string Database type for cleanup

---Create a new execution context
---@param script EtlScript? Parsed script (optional, can be set later)
---@return EtlContext
function EtlContext.new(script)
  local self = setmetatable({}, EtlContext)

  self.results = {}
  self.variables = script and vim.deepcopy(script.variables) or {}
  self.current_block = nil
  self.start_time = os.clock()
  self.errors = {}
  self.status = "pending"
  self.script = script
  self.block_timings = {}
  self.temp_tables = {}

  return self
end

---Set the script for this context (if not provided in constructor)
---@param script EtlScript
function EtlContext:set_script(script)
  self.script = script
  -- Merge script variables (don't overwrite existing)
  for name, value in pairs(script.variables) do
    if self.variables[name] == nil then
      self.variables[name] = value
    end
  end
end

---Mark execution as started
function EtlContext:start()
  self.status = "running"
  self.start_time = os.clock()
end

---Mark execution as complete
---@param success boolean Whether execution succeeded
function EtlContext:finish(success)
  if success then
    self.status = "success"
  else
    self.status = "error"
  end
end

---Mark execution as cancelled
function EtlContext:cancel()
  self.status = "cancelled"
end

---Set current block being executed
---@param block_name string
function EtlContext:set_current_block(block_name)
  self.current_block = block_name
end

---Store a block's result
---@param block_name string Block name
---@param result EtlResult Result to store
function EtlContext:set_result(block_name, result)
  result.block_name = block_name
  self.results[block_name] = result
end

---Get a block's result
---@param block_name string Block name
---@return EtlResult? result Result or nil if not found
function EtlContext:get_result(block_name)
  return self.results[block_name]
end

---Get rows for @input directive
---Convenience method that extracts just the rows array
---@param block_name string Input block name
---@return table[]? rows Array of row objects or nil
function EtlContext:get_input_rows(block_name)
  local result = self.results[block_name]
  if result then
    return result.rows
  end
  return nil
end

---Get columns for @input directive
---@param block_name string Input block name
---@return table<string, ColumnMeta>? columns Column metadata or nil
function EtlContext:get_input_columns(block_name)
  local result = self.results[block_name]
  if result then
    return result.columns
  end
  return nil
end

---Store an error for a block
---@param block_name string Block name
---@param error EtlBlockError Error details
function EtlContext:set_error(block_name, error)
  self.errors[block_name] = error
end

---Get error for a block
---@param block_name string Block name
---@return EtlBlockError? error Error or nil
function EtlContext:get_error(block_name)
  return self.errors[block_name]
end

---Check if a block has an error
---@param block_name string Block name
---@return boolean
function EtlContext:has_error(block_name)
  return self.errors[block_name] ~= nil
end

---Check if any block has an error
---@return boolean
function EtlContext:has_any_error()
  return next(self.errors) ~= nil
end

---Set a variable value
---@param name string Variable name
---@param value any Variable value
function EtlContext:set_variable(name, value)
  self.variables[name] = value
end

---Get a variable value
---@param name string Variable name
---@param default any? Default value if not found
---@return any
function EtlContext:get_variable(name, default)
  local value = self.variables[name]
  if value == nil then
    return default
  end
  return value
end

---Record block execution time
---@param block_name string Block name
---@param time_ms number Execution time in milliseconds
function EtlContext:set_block_timing(block_name, time_ms)
  self.block_timings[block_name] = time_ms
end

---Get block execution time
---@param block_name string Block name
---@return number? time_ms Execution time or nil
function EtlContext:get_block_timing(block_name)
  return self.block_timings[block_name]
end

---Get total execution time so far
---@return number time_ms Total time in milliseconds
function EtlContext:get_total_time()
  return (os.clock() - self.start_time) * 1000
end

---Register a temp table created for cross-server transfer
---@param info TempTableInfo Temp table information
function EtlContext:register_temp_table(info)
  self.temp_tables[info.name] = info
end

---Get all temp tables that need cleanup
---@return TempTableInfo[]
function EtlContext:get_temp_tables()
  local tables = {}
  for _, info in pairs(self.temp_tables) do
    table.insert(tables, info)
  end
  return tables
end

---Create a read-only results proxy for Lua sandbox
---This allows Lua blocks to access results.block_name.rows syntax
---@return table proxy Read-only results proxy
function EtlContext:create_results_proxy()
  local ctx = self
  local proxy = {}

  setmetatable(proxy, {
    __index = function(_, block_name)
      local result = ctx.results[block_name]
      if not result then
        return nil
      end

      -- Return a read-only view of the result
      return {
        rows = result.rows,
        columns = result.columns,
        row_count = result.row_count,
        rows_affected = result.rows_affected,
      }
    end,
    __newindex = function()
      error("Cannot modify results (read-only)", 2)
    end,
    __pairs = function()
      return pairs(ctx.results)
    end,
  })

  return proxy
end

---Create a read-only variables proxy for Lua sandbox
---@return table proxy Read-only variables proxy with write capability
function EtlContext:create_vars_proxy()
  local ctx = self

  local proxy = {}
  setmetatable(proxy, {
    __index = function(_, name)
      return ctx.variables[name]
    end,
    __newindex = function(_, name, value)
      ctx.variables[name] = value
    end,
    __pairs = function()
      return pairs(ctx.variables)
    end,
  })

  return proxy
end

---Get execution summary
---@return EtlExecutionSummary
function EtlContext:get_summary()
  local completed = 0
  local failed = 0
  local skipped = 0
  local total_rows = 0

  if self.script then
    for _, block in ipairs(self.script.blocks) do
      if self.results[block.name] then
        completed = completed + 1
        total_rows = total_rows + (self.results[block.name].row_count or 0)
      elseif self.errors[block.name] then
        failed = failed + 1
      else
        skipped = skipped + 1
      end
    end
  end

  return {
    status = self.status,
    total_blocks = self.script and #self.script.blocks or 0,
    completed_blocks = completed,
    failed_blocks = failed,
    skipped_blocks = skipped,
    total_rows = total_rows,
    total_time_ms = self:get_total_time(),
    errors = self.errors,
  }
end

---@class EtlExecutionSummary
---@field status EtlStatus
---@field total_blocks number
---@field completed_blocks number
---@field failed_blocks number
---@field skipped_blocks number
---@field total_rows number
---@field total_time_ms number
---@field errors table<string, EtlBlockError>

---Convert Node.js result to EtlResult
---@param node_result table Result from Node.js query execution
---@param block_name string Block name
---@param block_type "sql"|"lua" Block type
---@param execution_time_ms number Execution time
---@param generated_sql string? Generated SQL for Lua blocks
---@return EtlResult
function EtlContext.result_from_node(node_result, block_name, block_type, execution_time_ms, generated_sql)
  local rows = {}
  local columns = {}
  local row_count = 0
  local rows_affected = nil

  -- Extract from resultSets
  if node_result.resultSets and node_result.resultSets[1] then
    local rs = node_result.resultSets[1]
    rows = rs.rows or {}
    row_count = #rows

    -- Convert columns to our format
    if rs.columns then
      local idx = 1
      for col_name, col_info in pairs(rs.columns) do
        columns[col_name] = {
          name = col_name,
          type = col_info.type,
          index = idx,
        }
        idx = idx + 1
      end
    end
  end

  -- Extract rowsAffected from metadata
  if node_result.metadata and node_result.metadata.rowsAffected then
    local ra = node_result.metadata.rowsAffected
    if type(ra) == "table" then
      rows_affected = 0
      for _, count in ipairs(ra) do
        rows_affected = rows_affected + (count or 0)
      end
    else
      rows_affected = ra
    end
  end

  return {
    rows = rows,
    columns = columns,
    row_count = row_count,
    rows_affected = rows_affected,
    execution_time_ms = execution_time_ms,
    block_name = block_name,
    block_type = block_type,
    generated_sql = generated_sql,
    output_type = "sql",
  }
end

---Create EtlResult from Lua data() return
---@param data table[] Array of row objects
---@param block_name string Block name
---@param execution_time_ms number Execution time
---@return EtlResult
function EtlContext.result_from_data(data, block_name, execution_time_ms)
  -- Infer columns from first row
  local columns = {}
  if data[1] then
    local idx = 1
    for col_name, _ in pairs(data[1]) do
      columns[col_name] = {
        name = col_name,
        type = nil, -- Unknown type from Lua data
        index = idx,
      }
      idx = idx + 1
    end
  end

  return {
    rows = data,
    columns = columns,
    row_count = #data,
    rows_affected = nil,
    execution_time_ms = execution_time_ms,
    block_name = block_name,
    block_type = "lua",
    generated_sql = nil,
    output_type = "data",
  }
end

---Pretty print context for debugging
---@return string
function EtlContext:dump()
  local lines = { "=== ETL Context ===" }

  table.insert(lines, string.format("Status: %s", self.status))
  table.insert(lines, string.format("Current block: %s", self.current_block or "(none)"))
  table.insert(lines, string.format("Total time: %.2f ms", self:get_total_time()))

  table.insert(lines, "\nVariables:")
  for name, value in pairs(self.variables) do
    table.insert(lines, string.format("  %s = %s", name, vim.inspect(value)))
  end

  table.insert(lines, "\nResults:")
  for name, result in pairs(self.results) do
    table.insert(
      lines,
      string.format(
        "  %s: %d rows, %.2f ms (%s)",
        name,
        result.row_count,
        result.execution_time_ms,
        result.output_type
      )
    )
  end

  if next(self.errors) then
    table.insert(lines, "\nErrors:")
    for name, err in pairs(self.errors) do
      table.insert(lines, string.format("  %s: %s", name, err.message))
    end
  end

  return table.concat(lines, "\n")
end

return EtlContext
