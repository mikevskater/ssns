---@class EtlHistoryMetadata
---ETL-specific metadata stored in QueryHistoryEntry
---@field script_type "etl" Type marker for ETL executions
---@field script_name string File name of .ssns script
---@field script_path string? Full path to script file
---@field blocks_total number Total blocks in script
---@field blocks_completed number Blocks successfully executed
---@field blocks_failed number Blocks that failed
---@field blocks_skipped number Blocks that were skipped
---@field block_results EtlBlockResult[] Per-block execution details

---@class EtlBlockResult
---Block-level execution result for history
---@field name string Block name
---@field type "sql"|"lua" Block type
---@field server string? Server used
---@field database string? Database used
---@field description string? Block description
---@field status "success"|"error"|"skipped"|"pending" Block status
---@field execution_time_ms number Block duration
---@field row_count number? Rows returned/affected
---@field rows_affected number? For INSERT/UPDATE/DELETE
---@field error_message string? Error if failed
---@field generated_sql string? For Lua blocks, the SQL that was generated
---@field input_block string? Reference to @input block

---@class EtlHistoryModule
---Module for handling ETL-specific history entries
local M = {}

local QueryHistory = require('nvim-ssns.query_history')

---Create ETL history metadata from execution context
---@param script EtlScript Parsed ETL script
---@param context EtlContext Execution context with results
---@return EtlHistoryMetadata metadata
function M.create_metadata(script, context)
  local block_results = {}
  local completed = 0
  local failed = 0
  local skipped = 0

  for _, block in ipairs(script.blocks) do
    local result = context:get_result(block.name)
    local timing = context.block_timings[block.name]
    local error_msg = context.errors[block.name]

    ---@type EtlBlockResult
    local block_result = {
      name = block.name,
      type = block.type,
      server = block.server,
      database = block.database,
      description = block.description,
      status = "pending",
      execution_time_ms = timing or 0,
    }

    if error_msg then
      block_result.status = "error"
      block_result.error_message = error_msg
      failed = failed + 1
    elseif result then
      block_result.status = "success"
      block_result.row_count = result.row_count
      block_result.rows_affected = result.rows_affected
      block_result.generated_sql = result.generated_sql
      completed = completed + 1
    else
      -- Check if block was skipped
      if block.options and block.options.skip_on_empty then
        block_result.status = "skipped"
        skipped = skipped + 1
      end
    end

    if block.input then
      block_result.input_block = block.input
    end

    table.insert(block_results, block_result)
  end

  ---@type EtlHistoryMetadata
  local metadata = {
    script_type = "etl",
    script_name = script.source_file and vim.fn.fnamemodify(script.source_file, ":t") or "untitled.ssns",
    script_path = script.source_file,
    blocks_total = #script.blocks,
    blocks_completed = completed,
    blocks_failed = failed,
    blocks_skipped = skipped,
    block_results = block_results,
  }

  return metadata
end

---Add ETL execution to history
---@param bufnr number Buffer number
---@param script EtlScript Parsed script
---@param context EtlContext Execution context
---@param summary EtlExecutionSummary Execution summary
---@return boolean success
function M.add_to_history(bufnr, script, context, summary)
  -- Get buffer name from script source or buffer
  local buffer_name
  if script.source_file then
    buffer_name = vim.fn.fnamemodify(script.source_file, ":t")
  else
    buffer_name = vim.api.nvim_buf_get_name(bufnr)
    if buffer_name == "" then
      buffer_name = string.format("ETL Buffer %d", bufnr)
    end
  end

  -- Determine primary server/database (from first block or most used)
  local primary_server, primary_database
  local server_counts = {}
  for _, block in ipairs(script.blocks) do
    if block.server then
      server_counts[block.server] = (server_counts[block.server] or 0) + 1
      if not primary_server then
        primary_server = block.server
        primary_database = block.database
      end
    end
  end

  -- Find most common server
  local max_count = 0
  for server, count in pairs(server_counts) do
    if count > max_count then
      max_count = count
      primary_server = server
    end
  end

  -- Create ETL metadata
  local etl_metadata = M.create_metadata(script, context)

  -- Get full script content for history
  local script_content
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    script_content = table.concat(lines, "\n")
  else
    -- Reconstruct from blocks (fallback)
    local parts = {}
    for name, value in pairs(script.variables) do
      table.insert(parts, string.format("--@var %s = %s", name, vim.inspect(value)))
    end
    table.insert(parts, "")
    for _, block in ipairs(script.blocks) do
      if block.type == "lua" then
        table.insert(parts, string.format("--@lua %s", block.name))
      else
        table.insert(parts, string.format("--@block %s", block.name))
      end
      if block.server then
        table.insert(parts, string.format("--@server %s", block.server))
      end
      if block.database then
        table.insert(parts, string.format("--@database %s", block.database))
      end
      if block.description then
        table.insert(parts, string.format("--@description %s", block.description))
      end
      table.insert(parts, block.content)
      table.insert(parts, "")
    end
    script_content = table.concat(parts, "\n")
  end

  -- Calculate total row count
  local total_rows = 0
  for _, block_result in ipairs(etl_metadata.block_results) do
    if block_result.row_count then
      total_rows = total_rows + block_result.row_count
    end
    if block_result.rows_affected then
      total_rows = total_rows + block_result.rows_affected
    end
  end

  -- Create history entry
  ---@type QueryHistoryEntry
  local entry = {
    query = script_content,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    execution_time_ms = summary.total_time_ms,
    status = summary.success and "success" or "error",
    source = "executed",
    row_count = total_rows,
    server_name = primary_server or "unknown",
    database = primary_database,
    -- ETL-specific metadata
    etl_metadata = etl_metadata,
  }

  -- Add error message if failed
  if not summary.success and summary.error then
    entry.error_message = summary.error
  end

  return QueryHistory.add_entry(bufnr, buffer_name, entry)
end

---Check if a history entry is an ETL execution
---@param entry QueryHistoryEntry
---@return boolean is_etl
function M.is_etl_entry(entry)
  return entry.etl_metadata ~= nil and entry.etl_metadata.script_type == "etl"
end

---Get display icon for ETL entry
---@param entry QueryHistoryEntry
---@return string icon
function M.get_etl_icon(entry)
  if not M.is_etl_entry(entry) then
    return ""
  end

  local meta = entry.etl_metadata
  if meta.blocks_failed > 0 then
    return "[ETL✗]"
  elseif meta.blocks_completed == meta.blocks_total then
    return "[ETL✓]"
  else
    return "[ETL…]"
  end
end

---Get summary line for ETL entry
---@param entry QueryHistoryEntry
---@return string summary
function M.get_etl_summary(entry)
  if not M.is_etl_entry(entry) then
    return ""
  end

  local meta = entry.etl_metadata
  local parts = {
    meta.script_name,
    string.format("%d/%d blocks", meta.blocks_completed, meta.blocks_total),
  }

  if meta.blocks_failed > 0 then
    table.insert(parts, string.format("%d failed", meta.blocks_failed))
  end

  if meta.blocks_skipped > 0 then
    table.insert(parts, string.format("%d skipped", meta.blocks_skipped))
  end

  return table.concat(parts, " | ")
end

---Format block results for display
---@param entry QueryHistoryEntry
---@return string[] lines Formatted lines for display
function M.format_block_results(entry)
  if not M.is_etl_entry(entry) then
    return {}
  end

  local lines = {}
  local meta = entry.etl_metadata

  table.insert(lines, "")
  table.insert(lines, string.format("-- ETL Script: %s", meta.script_name))
  table.insert(lines, string.format("-- Blocks: %d total, %d completed, %d failed, %d skipped",
    meta.blocks_total, meta.blocks_completed, meta.blocks_failed, meta.blocks_skipped))
  table.insert(lines, "-- " .. string.rep("─", 50))
  table.insert(lines, "")

  for i, block in ipairs(meta.block_results) do
    local status_icon
    if block.status == "success" then
      status_icon = "✓"
    elseif block.status == "error" then
      status_icon = "✗"
    elseif block.status == "skipped" then
      status_icon = "○"
    else
      status_icon = "·"
    end

    local location = ""
    if block.server or block.database then
      local parts = {}
      if block.server then table.insert(parts, block.server) end
      if block.database then table.insert(parts, block.database) end
      location = " (" .. table.concat(parts, ".") .. ")"
    end

    local timing = block.execution_time_ms > 0
      and string.format(" - %dms", block.execution_time_ms)
      or ""

    local row_info = ""
    if block.row_count and block.row_count > 0 then
      row_info = string.format(" - %d rows", block.row_count)
    elseif block.rows_affected and block.rows_affected > 0 then
      row_info = string.format(" - %d affected", block.rows_affected)
    end

    table.insert(lines, string.format("-- [%d] %s %s [%s]%s%s%s",
      i, status_icon, block.name, block.type, location, timing, row_info))

    if block.description then
      table.insert(lines, string.format("--     %s", block.description))
    end

    if block.error_message then
      table.insert(lines, string.format("--     ERROR: %s", block.error_message))
    end

    if block.generated_sql then
      table.insert(lines, "--     Generated SQL:")
      for _, sql_line in ipairs(vim.split(block.generated_sql, "\n")) do
        table.insert(lines, string.format("--       %s", sql_line))
      end
    end
  end

  return lines
end

return M
