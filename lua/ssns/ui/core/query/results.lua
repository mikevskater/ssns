---@class QueryResults
---Query results display and formatting
local QueryResults = {}

local KeymapManager = require('ssns.keymap_manager')

---Reference to parent UiQuery module (set during init)
---@type UiQuery
local UiQuery

---Parse divider format string and generate lines
---@param format string Divider format (e.g., "20#", "10-\n10-", "5-(%row_count% rows)5-", "%fit%=", "%fit_results%-")
---@param metadata table Metadata for variable replacement (row_count, col_count, result_set_num, total_result_sets, run_time, total_time, chunk_number, batch_number, date, time, result_width)
---@return string[] lines Array of divider lines
function QueryResults.parse_divider_format(format, metadata)
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

---Format a single result set with ContentBuilder for styled display
---Supports multi-line cells, row numbers, and row separators (SSMS style)
---@param result_set table Array of row objects
---@param columns_metadata table? Column metadata from Node.js { colName: { index: 0, type: string, ... }, ... }
---@param builder ContentBuilder ContentBuilder instance to add to
---@param results_config table Results display configuration
---@return number result_width Width of the formatted result table
function QueryResults.format_single_result_set_styled(result_set, columns_metadata, builder, results_config)
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
  local row_separators_config = results_config.row_separators
  if row_separators_config == nil then row_separators_config = "auto" end

  -- Determine whether to show row separators
  -- "auto" = show for multi-line modes (word/char), hide for truncate
  -- true/false = explicit override
  local show_row_separators
  if row_separators_config == "auto" then
    show_row_separators = (wrap_mode ~= "truncate")
  else
    show_row_separators = (row_separators_config == true)
  end

  -- Max rows to display (0 = no limit, >0 = limit)
  local max_display_rows = results_config.max_display_rows or 0
  local total_rows = #result_set
  local display_rows_truncated = max_display_rows > 0 and total_rows > max_display_rows

  -- In truncate mode, preserve_newlines is ignored (always single line)
  if wrap_mode == "truncate" then
    preserve_newlines = false
  end

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
        -- Replace tabs with spaces (tabs break alignment as they count as 1 char but display as multiple)
        value_str = value_str:gsub("\t", "    ")
      end

      -- If no max_col_width, find the longest line in the value
      if not max_col_width then
        -- Split by newlines and find max line length
        local value_lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
        for _, line in ipairs(value_lines) do
          if #line > widths[i] then
            widths[i] = #line
          end
        end
      else
        -- Cap at max_col_width
        if widths[i] < max_col_width then
          local value_lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
          for _, line in ipairs(value_lines) do
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

  -- Pre-build row separator for caching (same for all rows)
  local cached_row_separator = nil
  if show_row_separators then
    cached_row_separator = ContentBuilder.build_row_separator_with_rownum(col_info, border_style, row_num_width)
  end

  -- Build data rows with multi-line support and row separators
  -- Limit to max_display_rows if configured (0 = no limit)
  local rows_to_display = (max_display_rows > 0) and math.min(total_rows, max_display_rows) or total_rows

  if total_rows > 0 then
    for row_idx = 1, rows_to_display do
      local row = result_set[row_idx]
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
          -- Replace tabs with spaces (tabs break alignment as they count as 1 char but display as multiple)
          value_str = value_str:gsub("\t", "    ")
        end

        -- Wrap or truncate the text based on mode
        local wrapped_lines
        if wrap_mode == "truncate" then
          -- Truncate mode: always single line, cut at max_col_width or first newline
          local effective_width = max_col_width or widths[i]
          wrapped_lines = ContentBuilder.wrap_text(value_str, effective_width, "truncate", false)
        elseif max_col_width and widths[i] >= max_col_width then
          -- Multi-line wrap mode with max width reached
          wrapped_lines = ContentBuilder.wrap_text(value_str, widths[i], wrap_mode, preserve_newlines)
        elseif preserve_newlines and value_str:match("[\r\n]") then
          -- Just split by newlines, no wrapping needed
          wrapped_lines = vim.split(value_str:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
        else
          -- Use parentheses to capture only the string (gsub returns string, count)
          wrapped_lines = { (value_str:gsub("[\r\n]", " ")) }
        end

        table.insert(cell_lines, {
          lines = wrapped_lines,
          width = widths[i],
          datatype = column_types[col.key],
          is_null = is_null,
        })
      end

      -- Add row separator before each row (except first) if enabled
      if cached_row_separator and row_idx > 1 then
        builder:add_cached_row_separator(cached_row_separator)
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

  -- Show truncation message if rows were limited
  if display_rows_truncated then
    builder:blank()
    builder:styled(
      string.format("(Showing %d of %d rows - use export for full data)", rows_to_display, total_rows),
      "muted"
    )
  end

  return result_width
end

---Format all result sets with ContentBuilder for styled display
---@param resultSets table Array of result set objects
---@param sql string? The SQL query (unused but kept for API compatibility)
---@param execution_time_ms number? Execution time in milliseconds
---@param query_metadata table? Query metadata including rowsAffected and timing
---@return ContentBuilder builder ContentBuilder with all styled content
---@return table[] result_set_ranges Array of {start_line, end_line, index} for cursor-based result set detection
function QueryResults.format_results_styled(resultSets, sql, execution_time_ms, query_metadata)
  local ContentBuilder = require('ssns.ui.core.content_builder')
  local Config = require('ssns.config')
  local results_config = Config.get_results()
  local ui_config = Config.get_ui()

  -- Track line ranges for each result set (for cursor-based export)
  local result_set_ranges = {}

  local builder = ContentBuilder.new()

  -- Validate input
  if type(resultSets) ~= "table" then
    builder:line(tostring(resultSets))
    return builder, result_set_ranges
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

      return builder, result_set_ranges
    end

    -- No metadata, just show completion message
    builder:styled("Commands completed successfully.", "success")
    if execution_time_ms then
      local time_str = execution_time_ms < 1000 and string.format("%.0fms", execution_time_ms) or string.format("%.2fs", execution_time_ms / 1000)
      builder:styled(string.format("Total execution time: %s", time_str), "muted")
    end
    builder:blank()
    return builder, result_set_ranges
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
          local divider_lines = QueryResults.parse_divider_format(divider_format, metadata)
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

    -- Track start line for this result set (1-indexed for cursor position)
    local start_line = builder:line_count() + 1

    -- Format this result set
    QueryResults.format_single_result_set_styled(rows, resultSet.columns, builder, results_config)

    -- Track end line for this result set
    local end_line = builder:line_count()
    table.insert(result_set_ranges, { start_line = start_line, end_line = end_line, index = i })
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

  return builder, result_set_ranges
end

---Display query results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@param sql string The SQL that was executed
---@param execution_time_ms number? Execution time in milliseconds
---@param query_bufnr number? The query buffer number (for per-buffer results tracking)
function QueryResults.display_results(result, sql, execution_time_ms, query_bufnr)
  local ContentBuilder = require('ssns.ui.core.content_builder')

  -- Use provided buffer or current buffer
  query_bufnr = query_bufnr or vim.api.nvim_get_current_buf()

  -- Store results for this specific query buffer
  UiQuery.buffer_results[query_bufnr] = {
    resultSets = result.resultSets,
    sql = sql,
    execution_time_ms = execution_time_ms,
    metadata = result.metadata,
  }

  -- Generate unique results buffer name based on query buffer
  local query_buf_name = vim.api.nvim_buf_get_name(query_bufnr)
  local short_name = query_buf_name:match("%[([^%]]+)%]") or tostring(query_bufnr)
  local results_buf_name = string.format("SSNS Results [%s]", short_name)

  -- Try to find existing results buffer for this query buffer
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name == results_buf_name then
        result_buf = buf
        break
      end
    end
  end

  -- Create new buffer if not found
  if not result_buf then
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, results_buf_name)
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
    -- Store association: results buffer -> query buffer
    vim.api.nvim_buf_set_var(result_buf, 'ssns_query_bufnr', query_bufnr)
  end

  -- Format results with styled ContentBuilder (also returns line ranges for cursor-based export)
  local builder, result_set_ranges = QueryResults.format_results_styled(result.resultSets, sql, execution_time_ms, result.metadata)

  -- Store result set ranges for cursor-based export
  UiQuery.buffer_results[query_bufnr].result_set_ranges = result_set_ranges

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
  QueryResults.setup_results_keymaps(result_buf)
end

---Toggle the results window for a specific query buffer (show if hidden, hide if visible)
---@param query_bufnr number? The query buffer number (defaults to current buffer or associated query buffer)
function QueryResults.toggle_results(query_bufnr)
  local ContentBuilder = require('ssns.ui.core.content_builder')
  local current_buf = vim.api.nvim_get_current_buf()

  -- Determine the query buffer:
  -- 1. If explicitly provided, use it
  -- 2. If current buffer is a results buffer, get its associated query buffer
  -- 3. If current buffer is a query buffer, use it
  -- 4. Otherwise, no results to show
  if not query_bufnr then
    -- Check if current buffer is a results buffer
    local ok, associated_query = pcall(vim.api.nvim_buf_get_var, current_buf, 'ssns_query_bufnr')
    if ok and associated_query then
      query_bufnr = associated_query
    elseif UiQuery.query_buffers[current_buf] then
      -- Current buffer is a query buffer
      query_bufnr = current_buf
    else
      vim.notify("SSNS: No query buffer context - run a query first", vim.log.levels.INFO)
      return
    end
  end

  -- Generate the expected results buffer name
  local query_buf_name = vim.api.nvim_buf_get_name(query_bufnr)
  local short_name = query_buf_name:match("%[([^%]]+)%]") or tostring(query_bufnr)
  local results_buf_name = string.format("SSNS Results [%s]", short_name)

  -- Find existing results buffer for this query buffer
  local result_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name == results_buf_name then
        result_buf = buf
        break
      end
    end
  end

  -- If no results buffer exists, try to recreate from stored results
  if not result_buf then
    local stored = UiQuery.buffer_results[query_bufnr]
    if not stored or not stored.resultSets then
      vim.notify("SSNS: No results to show for this buffer", vim.log.levels.INFO)
      return
    end

    -- Recreate the results buffer from stored data
    result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_buf, results_buf_name)
    vim.api.nvim_buf_set_option(result_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_var(result_buf, 'ssns_query_bufnr', query_bufnr)

    -- Re-format and populate with styled results
    local builder, result_set_ranges = QueryResults.format_results_styled(
      stored.resultSets,
      stored.sql,
      stored.execution_time_ms,
      stored.metadata
    )

    -- Update stored ranges in case they weren't saved before
    stored.result_set_ranges = result_set_ranges

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
    -- Results window is visible, save height and close it
    UiQuery.buffer_results_window_height[query_bufnr] = vim.api.nvim_win_get_height(result_win)
    vim.api.nvim_win_close(result_win, false)
  else
    -- Results window is hidden, open it in a split
    vim.cmd('botright split')
    vim.api.nvim_win_set_buf(0, result_buf)
    local new_win = vim.api.nvim_get_current_win()

    -- Restore previous height or use default of 10
    local height = UiQuery.buffer_results_window_height[query_bufnr] or 10
    vim.api.nvim_win_set_height(new_win, height)

    -- Setup keymaps for results buffer
    QueryResults.setup_results_keymaps(result_buf)
  end
end

---Show controls popup for results buffer
function QueryResults.show_results_controls()
  local UiFloat = require('ssns.ui.core.float')
  local km = KeymapManager.get_group("results")
  local query_km = KeymapManager.get_group("query")

  local controls = {
    {
      header = "Results Buffer",
      keys = {
        { key = km.close or "q", desc = "Close results window" },
        { key = km.toggle or query_km.toggle_results or "C-r", desc = "Toggle results window" },
        { key = km.export_csv or "A-e", desc = "Export cursor result set to CSV" },
        { key = km.export_all_csv or "A-E", desc = "Export ALL result sets to CSV files" },
        { key = km.yank_csv or "A-y", desc = "Yank cursor result set as CSV" },
        { key = km.yank_all_csv or "A-Y", desc = "Yank ALL result sets as CSV" },
      },
    },
  }

  UiFloat._show_controls_popup(controls)
end

---Save results window height before closing (per query buffer)
---@param win number? Window handle (nil = current window)
local function save_results_window_height(win)
  win = win or vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(win) then
    local result_buf = vim.api.nvim_win_get_buf(win)
    local ok, query_bufnr = pcall(vim.api.nvim_buf_get_var, result_buf, 'ssns_query_bufnr')
    if ok and query_bufnr then
      UiQuery.buffer_results_window_height[query_bufnr] = vim.api.nvim_win_get_height(win)
    end
  end
end

---Setup keymaps for the results buffer
---@param result_buf number The results buffer number
function QueryResults.setup_results_keymaps(result_buf)
  local QueryExport = require('ssns.ui.core.query.export')
  local km = KeymapManager.get_group("results")
  local query_km = KeymapManager.get_group("query")

  local keymaps = {
    -- Close results window (save height first)
    { mode = "n", lhs = km.close or "q", rhs = function()
      save_results_window_height()
      vim.cmd('close')
    end, desc = "Close results window" },

    -- Toggle results window
    { mode = "n", lhs = km.toggle or query_km.toggle_results or "<C-r>", rhs = function()
      QueryResults.toggle_results()
    end, desc = "Toggle results window" },

    -- Export cursor-hovered result set to CSV
    { mode = "n", lhs = km.export_csv or "<A-e>", rhs = function()
      QueryExport.export_results_to_csv()
    end, desc = "Export cursor result set to CSV" },

    -- Export ALL result sets to separate CSV files
    { mode = "n", lhs = km.export_all_csv or "<A-E>", rhs = function()
      QueryExport.export_all_results_to_csv()
    end, desc = "Export ALL result sets to CSV files" },

    -- Yank cursor-hovered result set as CSV to clipboard
    { mode = "n", lhs = km.yank_csv or "<A-y>", rhs = function()
      QueryExport.yank_results_as_csv()
    end, desc = "Yank cursor result set as CSV" },

    -- Yank ALL result sets as CSV to clipboard
    { mode = "n", lhs = km.yank_all_csv or "<A-Y>", rhs = function()
      QueryExport.yank_all_results_as_csv()
    end, desc = "Yank ALL result sets as CSV" },

    -- Show controls
    { mode = "n", lhs = "?", rhs = function()
      QueryResults.show_results_controls()
    end, desc = "Show controls" },
  }

  KeymapManager.set_multiple(result_buf, keymaps, true)
  KeymapManager.mark_group_active(result_buf, "results")

  -- Set up autocmd to save window height when closed by any means
  -- Use BufWinLeave which fires when buffer leaves a window (i.e., window closes)
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = result_buf,
    callback = function()
      -- Save the height of the window that's being closed (per query buffer)
      -- At this point, the window is still valid
      local win = vim.fn.bufwinid(result_buf)
      if win ~= -1 and vim.api.nvim_win_is_valid(win) then
        local ok, query_bufnr = pcall(vim.api.nvim_buf_get_var, result_buf, 'ssns_query_bufnr')
        if ok and query_bufnr then
          UiQuery.buffer_results_window_height[query_bufnr] = vim.api.nvim_win_get_height(win)
        end
      end
    end,
    desc = "Save results window height on close",
  })
end

---Initialize the results module with parent reference
---@param parent UiQuery The parent UiQuery module
function QueryResults._init(parent)
  UiQuery = parent
end

return QueryResults
