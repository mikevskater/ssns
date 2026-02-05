---@class EtlResults
---ETL-specific result display with progress tracking
local EtlResults = {}

local ContentBuilder = require("nvim-float.content")

---@class EtlDisplayState
---@field script EtlScript The script being executed
---@field context EtlContext? Execution context (set after execution)
---@field bufnr number? Results buffer number
---@field winid number? Results window ID
---@field mode "progress"|"results" Current display mode

---Active display states by script
---@type table<string, EtlDisplayState>
local active_displays = {}

---Format a duration in milliseconds
---@param ms number Milliseconds
---@return string
local function format_duration(ms)
  if ms < 1000 then
    return string.format("%.0fms", ms)
  else
    return string.format("%.2fs", ms / 1000)
  end
end

---Format a row count with commas
---@param count number
---@return string
local function format_count(count)
  local formatted = tostring(count)
  local k
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then
      break
    end
  end
  return formatted
end

---Get status icon and style for block status
---@param status "pending"|"running"|"success"|"error"|"skipped"
---@return string icon, string style
local function get_status_icon(status)
  local icons = {
    pending = { "○", "muted" },
    running = { "◐", "info" },
    success = { "●", "success" },
    error = { "✗", "error" },
    skipped = { "◌", "muted" },
  }
  local icon_info = icons[status] or icons.pending
  return icon_info[1], icon_info[2]
end

---Build progress display content
---@param script EtlScript
---@param context EtlContext
---@param current_block_index number?
---@return ContentBuilder
function EtlResults.build_progress(script, context, current_block_index)
  local cb = ContentBuilder.new()

  -- Header
  cb:styled("ETL Execution", "header")
  cb:blank()

  -- Build pipeline visualization
  local block_names = {}
  for _, block in ipairs(script.blocks) do
    table.insert(block_names, block.name)
  end
  cb:styled(table.concat(block_names, " → "), "muted")
  cb:blank()
  cb:blank()

  -- Block status list
  for i, block in ipairs(script.blocks) do
    local status = "pending"
    local timing = nil

    if context:get_result(block.name) then
      status = "success"
      timing = context:get_block_timing(block.name)
    elseif context:get_error(block.name) then
      status = "error"
      timing = context:get_block_timing(block.name)
    elseif current_block_index and i == current_block_index then
      status = "running"
      timing = context:get_total_time()
    elseif current_block_index and i > current_block_index then
      status = "pending"
    end

    local icon, style = get_status_icon(status)

    -- Format: [1/3] block_name ................ STATUS (time)
    local prefix = string.format("[%d/%d] ", i, #script.blocks)
    local status_text = status:upper()
    if timing then
      status_text = status_text .. " (" .. format_duration(timing) .. ")"
    end

    -- Calculate dots
    local max_width = 60
    local name_width = #block.name
    local status_width = #status_text
    local dots_count = max_width - #prefix - name_width - status_width - 2
    if dots_count < 3 then
      dots_count = 3
    end
    local dots = string.rep(".", dots_count)

    -- Build line with spans
    cb:spans({
      { text = prefix },
      { text = block.name, style = "identifier" },
      { text = " " .. dots .. " ", style = "muted" },
      { text = status_text, style = style },
    })

    -- Show description or server/database on second line
    local details = {}
    if block.server then
      table.insert(details, block.server)
    end
    if block.database then
      table.insert(details, block.database)
    end
    if block.description then
      table.insert(details, block.description)
    end

    if #details > 0 then
      cb:styled("      " .. table.concat(details, " · "), "muted")
    end

    -- Show error message if failed
    if status == "error" then
      local err = context:get_error(block.name)
      if err then
        cb:styled("      Error: " .. (err.message or "Unknown error"), "error")
      end
    end

    cb:blank()
  end

  return cb
end

---Build final results display content
---@param script EtlScript
---@param context EtlContext
---@param opts table? Options {max_preview_rows: number}
---@return ContentBuilder
function EtlResults.build_results(script, context, opts)
  opts = opts or {}
  local max_preview_rows = opts.max_preview_rows or 10

  local cb = ContentBuilder.new()

  -- Header
  cb:styled("═══ ETL Results ═══", "header")
  cb:blank()

  -- Each block result
  for i, block in ipairs(script.blocks) do
    local result = context:get_result(block.name)
    local err = context:get_error(block.name)
    local timing = context:get_block_timing(block.name) or 0

    -- Block header
    local location = ""
    if block.server then
      location = block.server
      if block.database then
        location = location .. "." .. block.database
      end
    end

    local icon, style = get_status_icon(err and "error" or (result and "success" or "skipped"))

    -- Build block header line with spans
    local spans = {
      { text = string.format("[%d/%d] ", i, #script.blocks) },
      { text = icon .. " ", style = style },
      { text = block.name, style = "identifier" },
    }

    if location ~= "" then
      table.insert(spans, { text = " (" .. location .. ")", style = "muted" })
    end

    -- Row count and timing
    if result then
      local count_str
      if result.rows_affected then
        count_str = format_count(result.rows_affected) .. " rows affected"
      else
        count_str = format_count(result.row_count) .. " rows"
      end
      table.insert(spans, { text = " - " .. count_str .. " - " .. format_duration(timing), style = "muted" })
    elseif err then
      table.insert(spans, { text = " - FAILED - " .. format_duration(timing), style = "error" })
    end

    cb:spans(spans)

    -- Show error details
    if err then
      cb:styled("  Error: " .. (err.message or "Unknown error"), "error")
      if err.sql then
        cb:styled("  SQL: " .. err.sql:sub(1, 100) .. (err.sql:len() > 100 and "..." or ""), "muted")
      end
      cb:blank()
    end

    -- Show result preview (for SELECT results)
    if result and result.rows and #result.rows > 0 and result.row_count > 0 then
      -- Show generated SQL for Lua blocks
      if result.generated_sql then
        cb:styled("  Generated SQL:", "muted")
        local sql_preview = result.generated_sql:sub(1, 200)
        if result.generated_sql:len() > 200 then
          sql_preview = sql_preview .. "..."
        end
        cb:styled("  " .. sql_preview:gsub("\n", "\n  "), "sql")
        cb:blank()
      end

      -- Format result table
      local preview_rows = math.min(#result.rows, max_preview_rows)
      EtlResults._format_result_table(cb, result.rows, result.columns, preview_rows)

      if #result.rows > preview_rows then
        cb:styled(string.format("  ... and %d more rows", #result.rows - preview_rows), "muted")
      end
      cb:blank()
    elseif result and result.rows_affected then
      cb:styled("  Commands completed successfully.", "success")
      cb:blank()
    end

    -- Separator between blocks
    if i < #script.blocks then
      cb:separator("-", 60)
      cb:blank()
    end
  end

  -- Summary
  cb:blank()
  cb:styled("═══ Summary ═══", "header")
  cb:blank()

  local summary = context:get_summary()

  local status_str = summary.status:upper()
  local status_style = summary.status == "success" and "success" or "error"

  cb:spans({
    { text = "Status: " },
    { text = status_str, style = status_style },
  })

  cb:styled(
    string.format(
      "Blocks: %d/%d successful | Total rows: %s | Total time: %s",
      summary.completed_blocks,
      summary.total_blocks,
      format_count(summary.total_rows),
      format_duration(summary.total_time_ms)
    ),
    "muted"
  )

  if summary.failed_blocks > 0 then
    cb:blank()
    cb:styled(string.format("Failed blocks: %d", summary.failed_blocks), "error")
  end

  return cb
end

---Format a result table with columns
---@param cb ContentBuilder
---@param rows table[]
---@param columns table<string, ColumnMeta>?
---@param max_rows number
function EtlResults._format_result_table(cb, rows, columns, max_rows)
  if #rows == 0 then
    return
  end

  -- Get column names from first row
  local col_names = {}
  for col_name, _ in pairs(rows[1]) do
    table.insert(col_names, col_name)
  end
  table.sort(col_names)

  -- Calculate column widths
  local col_widths = {}
  for _, col_name in ipairs(col_names) do
    col_widths[col_name] = #col_name
  end

  local preview_rows = {}
  for i = 1, math.min(#rows, max_rows) do
    local row = rows[i]
    for _, col_name in ipairs(col_names) do
      local val = row[col_name]
      local val_str = val == nil and "NULL" or tostring(val)
      if #val_str > col_widths[col_name] then
        col_widths[col_name] = math.min(#val_str, 30) -- Max 30 chars per column
      end
    end
    table.insert(preview_rows, row)
  end

  -- Build header
  local header_parts = {}
  local separator_parts = {}
  for _, col_name in ipairs(col_names) do
    local width = col_widths[col_name]
    table.insert(header_parts, string.format("%-" .. width .. "s", col_name:sub(1, width)))
    table.insert(separator_parts, string.rep("-", width))
  end

  cb:styled("  | " .. table.concat(header_parts, " | ") .. " |", "header")
  cb:styled("  |-" .. table.concat(separator_parts, "-|-") .. "-|", "muted")

  -- Build rows
  for _, row in ipairs(preview_rows) do
    local row_parts = {}
    for _, col_name in ipairs(col_names) do
      local val = row[col_name]
      local val_str = val == nil and "NULL" or tostring(val)
      local width = col_widths[col_name]
      if #val_str > width then
        val_str = val_str:sub(1, width - 1) .. "…"
      end
      table.insert(row_parts, string.format("%-" .. width .. "s", val_str))
    end
    cb:line("  | " .. table.concat(row_parts, " | ") .. " |")
  end
end

---Create or get results buffer
---@param script_id string Unique script identifier
---@return number bufnr
local function get_or_create_buffer(script_id)
  local state = active_displays[script_id]
  if state and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  local buf_name = string.format("SSNS ETL [%s]", script_id)

  -- Check for existing buffer
  local existing = vim.fn.bufnr(buf_name)
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end

  -- Create new buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, buf_name)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "ssns-etl-results")

  return bufnr
end

---Show results window
---@param bufnr number Buffer number
---@return number winid
local function show_results_window(bufnr)
  -- Check if window already exists
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end

  -- Create split window
  vim.cmd("botright split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)
  vim.api.nvim_win_set_height(winid, 15)

  return winid
end

---Update buffer content from ContentBuilder
---@param bufnr number Buffer number
---@param builder ContentBuilder
local function update_buffer(bufnr, builder)
  local lines = builder:build_lines()
  local highlights = builder:build_highlights()

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_etl_results")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

---Create a progress callback for ETL execution
---@param script_id string Unique script identifier
---@param script EtlScript The script being executed
---@return fun(event: EtlProgressEvent) callback
function EtlResults.create_progress_callback(script_id, script)
  -- Initialize display state
  local bufnr = get_or_create_buffer(script_id)
  local winid = show_results_window(bufnr)

  active_displays[script_id] = {
    script = script,
    context = nil,
    bufnr = bufnr,
    winid = winid,
    mode = "progress",
  }

  return function(event)
    local state = active_displays[script_id]
    if not state then
      return
    end

    vim.schedule(function()
      if event.type == "start" then
        -- Show initial progress
        local context = require("nvim-ssns.etl.context").new(script)
        state.context = context
        local builder = EtlResults.build_progress(script, context, nil)
        update_buffer(state.bufnr, builder)
      elseif event.type == "block_start" then
        -- Update progress with current block
        if state.context and event.block_index then
          local builder = EtlResults.build_progress(script, state.context, event.block_index)
          update_buffer(state.bufnr, builder)
        end
      elseif event.type == "block_complete" or event.type == "block_error" then
        -- Update progress with completed block
        if state.context and event.block_index then
          -- Copy result/error to our tracking context
          if event.result then
            state.context:set_result(event.block.name, event.result)
          end
          if event.error then
            state.context:set_error(event.block.name, event.error)
          end
          if event.block_index then
            state.context:set_block_timing(
              event.block.name,
              event.result and event.result.execution_time_ms or 0
            )
          end
          local builder = EtlResults.build_progress(script, state.context, event.block_index + 1)
          update_buffer(state.bufnr, builder)
        end
      elseif event.type == "complete" then
        -- Switch to results mode
        state.mode = "results"
        if event.summary then
          local builder = EtlResults.build_results(script, state.context)
          update_buffer(state.bufnr, builder)
        end
      elseif event.type == "cancelled" then
        -- Show cancellation
        local builder = ContentBuilder.new()
        builder:styled("ETL Execution Cancelled", "warning")
        builder:blank()
        if state.context then
          local summary = state.context:get_summary()
          builder:styled(
            string.format("Completed %d/%d blocks before cancellation", summary.completed_blocks, summary.total_blocks),
            "muted"
          )
        end
        update_buffer(state.bufnr, builder)
      end
    end)
  end
end

---Display ETL results in a buffer (after execution)
---@param script EtlScript
---@param context EtlContext
---@param script_id string? Optional script identifier
function EtlResults.display(script, context, script_id)
  script_id = script_id or tostring(os.time())

  local bufnr = get_or_create_buffer(script_id)
  local winid = show_results_window(bufnr)

  active_displays[script_id] = {
    script = script,
    context = context,
    bufnr = bufnr,
    winid = winid,
    mode = "results",
  }

  local builder = EtlResults.build_results(script, context)
  update_buffer(bufnr, builder)
end

---Close ETL results display
---@param script_id string Script identifier
function EtlResults.close(script_id)
  local state = active_displays[script_id]
  if state then
    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
      vim.api.nvim_win_close(state.winid, true)
    end
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
      vim.api.nvim_buf_delete(state.bufnr, { force = true })
    end
    active_displays[script_id] = nil
  end
end

return EtlResults
