---@class QueryExport
---CSV export and yank functionality for query results
local QueryExport = {}

---Reference to parent UiQuery module (set during init)
---@type UiQuery
local UiQuery

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

---Get the query buffer number from current context
---@return number? query_bufnr The query buffer number or nil
local function get_current_query_bufnr()
  local current_buf = vim.api.nvim_get_current_buf()

  -- Check if current buffer is a results buffer with associated query buffer
  local ok, query_bufnr = pcall(vim.api.nvim_buf_get_var, current_buf, 'ssns_query_bufnr')
  if ok and query_bufnr then
    return query_bufnr
  end

  -- Check if current buffer is a query buffer
  if UiQuery.query_buffers[current_buf] then
    return current_buf
  end

  return nil
end

---Get the result set index that the cursor is currently on
---@param query_bufnr number The query buffer number
---@param cursor_line number The 1-indexed cursor line in the results buffer
---@return number? result_set_index The 1-indexed result set index, or nil if not found
local function get_result_set_at_cursor(query_bufnr, cursor_line)
  local stored = UiQuery.buffer_results[query_bufnr]
  if not stored or not stored.result_set_ranges then
    return nil
  end

  for _, range in ipairs(stored.result_set_ranges) do
    if cursor_line >= range.start_line and cursor_line <= range.end_line then
      return range.index
    end
  end

  -- If cursor is not within any result set, find the closest one
  -- (useful when cursor is on divider lines or execution time line)
  local closest_index = nil
  local min_distance = math.huge

  for _, range in ipairs(stored.result_set_ranges) do
    local distance = math.min(
      math.abs(cursor_line - range.start_line),
      math.abs(cursor_line - range.end_line)
    )
    if distance < min_distance then
      min_distance = distance
      closest_index = range.index
    end
  end

  return closest_index
end

---Convert result sets to CSV format
---@param resultSets table[] Array of result sets
---@param result_set_index number? Which result set to export (nil = first, 0 = all)
---@return string csv The CSV content
function QueryExport.results_to_csv(resultSets, result_set_index)
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

---Export results to CSV file and open in default application
---Exports only the result set under the cursor (or closest if cursor is between result sets)
---@param filepath string? Optional file path (uses config export_directory if not provided)
function QueryExport.export_results_to_csv(filepath)
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  -- Determine which result set to export based on cursor position
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed
  local result_set_index = get_result_set_at_cursor(query_bufnr, cursor_line)

  -- Default to first result set if we can't determine cursor position
  if not result_set_index then
    result_set_index = 1
  end

  local csv_content = QueryExport.results_to_csv(stored.resultSets, result_set_index)
  if csv_content == "" then
    vim.notify("SSNS: No data to export", vim.log.levels.WARN)
    return
  end

  -- Generate filename with timestamp and result set number
  local filename
  if #stored.resultSets > 1 then
    filename = os.date("ssns_result_set_" .. result_set_index .. "_%Y%m%d_%H%M%S.csv")
  else
    filename = os.date("ssns_results_%Y%m%d_%H%M%S.csv")
  end

  if not filepath then
    local Config = require('nvim-ssns.config')
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

  -- Count rows in this result set
  local row_count = 0
  if stored.resultSets[result_set_index] and stored.resultSets[result_set_index].rows then
    row_count = #stored.resultSets[result_set_index].rows
  end

  if #stored.resultSets > 1 then
    vim.notify(string.format("SSNS: Result set %d (%d rows) exported to %s", result_set_index, row_count, filepath), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Results (%d rows) exported to %s", row_count, filepath), vim.log.levels.INFO)
  end

  -- Open in default application
  open_with_default_app(filepath)
end

---Export ALL result sets to separate CSV files and open in default application
---Each result set is exported to its own file with sequential numbering
function QueryExport.export_all_results_to_csv()
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or #stored.resultSets == 0 then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  local Config = require('nvim-ssns.config')
  local query_config = Config.get_query()
  local export_dir = query_config.export_directory

  -- Determine export directory
  local dir
  if export_dir == "" then
    -- Empty string means prompt for location - use input to get directory
    dir = vim.fn.input({
      prompt = "Export directory: ",
      default = vim.fn.getcwd(),
      completion = "dir",
    })

    if dir == "" then
      vim.notify("SSNS: Export cancelled", vim.log.levels.INFO)
      return
    end
  else
    dir = export_dir or get_temp_dir()
  end

  dir = vim.fn.expand(dir)  -- Handle ~ and env vars

  -- Ensure directory exists
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- Generate base filename with timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local exported_files = {}
  local total_rows = 0

  for i, resultSet in ipairs(stored.resultSets) do
    local csv_content = QueryExport.results_to_csv(stored.resultSets, i)
    if csv_content ~= "" then
      local file_name = string.format("ssns_result_set_%d_%s.csv", i, timestamp)
      local file_path = dir .. "/" .. file_name

      -- Normalize path separators for Windows
      if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        file_path = file_path:gsub("/", "\\")
      end

      -- Write to file
      local file, write_err = io.open(file_path, "w")
      if file then
        file:write(csv_content)
        file:close()
        table.insert(exported_files, file_path)

        -- Count rows
        if resultSet.rows then
          total_rows = total_rows + #resultSet.rows
        end
      else
        vim.notify(string.format("SSNS: Failed to write %s: %s", file_name, write_err or "unknown error"), vim.log.levels.WARN)
      end
    end
  end

  if #exported_files == 0 then
    vim.notify("SSNS: No data to export", vim.log.levels.WARN)
    return
  end

  vim.notify(string.format("SSNS: Exported %d result sets (%d total rows) to %s", #exported_files, total_rows, dir), vim.log.levels.INFO)

  -- Open each file in default application
  for _, file_path in ipairs(exported_files) do
    open_with_default_app(file_path)
  end
end

---Yank cursor-hovered result set as CSV to clipboard
function QueryExport.yank_results_as_csv()
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets then
    vim.notify("SSNS: No results to copy", vim.log.levels.WARN)
    return
  end

  -- Determine which result set to yank based on cursor position
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed
  local result_set_index = get_result_set_at_cursor(query_bufnr, cursor_line)

  -- Default to first result set if we can't determine cursor position
  if not result_set_index then
    result_set_index = 1
  end

  local csv_content = QueryExport.results_to_csv(stored.resultSets, result_set_index)
  if csv_content == "" then
    vim.notify("SSNS: No data to copy", vim.log.levels.WARN)
    return
  end

  -- Copy to clipboard
  vim.fn.setreg("+", csv_content)
  vim.fn.setreg("*", csv_content)

  -- Count rows in this result set
  local row_count = 0
  if stored.resultSets[result_set_index] and stored.resultSets[result_set_index].rows then
    row_count = #stored.resultSets[result_set_index].rows
  end

  if #stored.resultSets > 1 then
    vim.notify(string.format("SSNS: Copied result set %d (%d rows) as CSV to clipboard", result_set_index, row_count), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Copied %d rows as CSV to clipboard", row_count), vim.log.levels.INFO)
  end
end

---Yank ALL result sets as CSV to clipboard (separated by blank lines)
function QueryExport.yank_all_results_as_csv()
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or #stored.resultSets == 0 then
    vim.notify("SSNS: No results to copy", vim.log.levels.WARN)
    return
  end

  -- Build CSV content for all result sets
  local csv_parts = {}
  local total_rows = 0

  for i, resultSet in ipairs(stored.resultSets) do
    local csv_content = QueryExport.results_to_csv(stored.resultSets, i)
    if csv_content ~= "" then
      -- Add result set header comment for multiple result sets
      if #stored.resultSets > 1 then
        table.insert(csv_parts, string.format("# Result Set %d", i))
      end
      table.insert(csv_parts, csv_content)

      -- Count rows
      if resultSet.rows then
        total_rows = total_rows + #resultSet.rows
      end
    end
  end

  if #csv_parts == 0 then
    vim.notify("SSNS: No data to copy", vim.log.levels.WARN)
    return
  end

  -- Join with double newline between result sets
  local full_csv = table.concat(csv_parts, "\n\n")

  -- Copy to clipboard
  vim.fn.setreg("+", full_csv)
  vim.fn.setreg("*", full_csv)

  vim.notify(string.format("SSNS: Copied %d result sets (%d total rows) as CSV to clipboard", #stored.resultSets, total_rows), vim.log.levels.INFO)
end

-- ============================================================================
-- Visual Selection Export Functions
-- ============================================================================

---Escape a value for TSV format
---@param value any The value to escape
---@return string escaped The escaped TSV value
local function escape_tsv_value(value)
  if value == nil or value == vim.NIL then
    return ""
  end

  local str = tostring(value)

  -- TSV: replace tabs with spaces, replace newlines with spaces
  str = str:gsub("\t", " ")
  str = str:gsub("\r\n", " ")
  str = str:gsub("\r", " ")
  str = str:gsub("\n", " ")

  return str
end

---Get visual selection bounds from current visual mode or marks
---@return {start_line: number, start_col: number, end_line: number, end_col: number, mode: string}?
local function get_visual_selection_bounds()
  local cur_mode = vim.fn.mode()
  local in_visual = cur_mode:match("[vV\x16]") ~= nil

  local start_pos, end_pos, vis_mode
  if in_visual then
    start_pos = vim.fn.getpos("v")
    end_pos = vim.fn.getpos(".")
    vis_mode = cur_mode
  else
    -- After visual mode exited, use marks
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
    vis_mode = vim.fn.visualmode()
  end

  if not start_pos or not end_pos then
    return nil
  end

  -- Normalize so start is before end
  local start_line = start_pos[2]
  local start_col = start_pos[3] - 1  -- Convert to 0-based
  local end_line = end_pos[2]
  local end_col = end_pos[3] - 1  -- Convert to 0-based

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  return {
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    mode = vis_mode,
  }
end

---Get selected cells based on visual selection and cell map
---@param cell_map table The cell map from ContentBuilder
---@param selection table The visual selection bounds
---@return {rows: number[], cols: number[], includes_header: boolean}?
local function get_selected_cells(cell_map, selection)
  if not cell_map or not selection then
    return nil
  end

  local start_line = selection.start_line
  local start_col = selection.start_col
  local end_line = selection.end_line
  local end_col = selection.end_col

  local result = {
    rows = {},
    cols = {},
    includes_header = false,
  }

  -- Check if row number column is in range (selects all columns)
  local row_num_selected = false
  if cell_map.row_num_column then
    row_num_selected = start_col < cell_map.row_num_column.end_col and end_col >= cell_map.row_num_column.start_col
  end

  -- Find columns in range
  local cols_set = {}
  if row_num_selected then
    -- Row number selected = all columns
    for _, col_info in ipairs(cell_map.columns or {}) do
      cols_set[col_info.index] = true
    end
  else
    for _, col_info in ipairs(cell_map.columns or {}) do
      -- Check if column overlaps with selection
      if start_col < col_info.end_col and end_col >= col_info.start_col then
        cols_set[col_info.index] = true
      end
    end
  end

  -- Convert to sorted array
  for col_idx in pairs(cols_set) do
    table.insert(result.cols, col_idx)
  end
  table.sort(result.cols)

  -- Check header
  if cell_map.header_lines then
    if start_line <= cell_map.header_lines.end_line and end_line >= cell_map.header_lines.start_line then
      result.includes_header = true
    end
  end

  -- Find rows in range
  local rows_set = {}
  for _, row_info in ipairs(cell_map.data_rows or {}) do
    if start_line <= row_info.end_line and end_line >= row_info.start_line then
      rows_set[row_info.index] = true
    end
  end

  -- Convert to sorted array
  for row_idx in pairs(rows_set) do
    table.insert(result.rows, row_idx)
  end
  table.sort(result.rows)

  return result
end

---Convert selected cells to output format (TSV or CSV)
---@param resultSet table The result set data
---@param selected_cells table Selected cells {rows, cols, includes_header}
---@param opts table Options: format ("tsv"|"csv"), include_headers (boolean)
---@return string output The formatted output
local function selection_to_output(resultSet, selected_cells, opts)
  opts = opts or {}
  local format = opts.format or "tsv"
  local include_headers = opts.include_headers ~= false

  local rows = resultSet.rows or {}
  local columns_metadata = resultSet.columns

  -- Get ordered column names
  local all_columns = {}
  if columns_metadata and type(columns_metadata) == "table" then
    for col_name, col_info in pairs(columns_metadata) do
      if col_name ~= vim.NIL then
        table.insert(all_columns, { name = col_name, index = col_info.index or 0 })
      end
    end
    table.sort(all_columns, function(a, b) return a.index < b.index end)
  elseif #rows > 0 then
    for key, _ in pairs(rows[1]) do
      table.insert(all_columns, { name = key, index = #all_columns + 1 })
    end
    table.sort(all_columns, function(a, b) return tostring(a.name) < tostring(b.name) end)
  end

  -- Filter to only selected columns
  local selected_columns = {}
  for _, col_idx in ipairs(selected_cells.cols) do
    if all_columns[col_idx] then
      table.insert(selected_columns, all_columns[col_idx])
    end
  end

  if #selected_columns == 0 then
    return ""
  end

  local separator = format == "tsv" and "\t" or ","
  local escape_fn = format == "tsv" and escape_tsv_value or escape_csv_value
  local output_lines = {}

  -- Add header row if requested
  if include_headers then
    local header_parts = {}
    for _, col in ipairs(selected_columns) do
      table.insert(header_parts, escape_fn(col.name))
    end
    table.insert(output_lines, table.concat(header_parts, separator))
  end

  -- Add data rows
  for _, row_idx in ipairs(selected_cells.rows) do
    local row = rows[row_idx]
    if row then
      local row_parts = {}
      for _, col in ipairs(selected_columns) do
        table.insert(row_parts, escape_fn(row[col.name]))
      end
      table.insert(output_lines, table.concat(row_parts, separator))
    end
  end

  return table.concat(output_lines, "\n")
end

---Yank visual selection to clipboard
---@param include_headers boolean? Include headers (nil = use config)
function QueryExport.yank_selection(include_headers)
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or not stored.cell_maps then
    vim.notify("SSNS: No results with cell tracking available", vim.log.levels.WARN)
    return
  end

  -- Get visual selection bounds
  local selection = get_visual_selection_bounds()
  if not selection then
    vim.notify("SSNS: No visual selection", vim.log.levels.WARN)
    return
  end

  -- Get config
  local Config = require('nvim-ssns.config')
  local results_config = Config.get_results()
  local format = results_config.selection_output_format or "tsv"
  if include_headers == nil then
    include_headers = results_config.include_headers_on_selection ~= false
  end

  -- Find which result set the selection is in
  local cursor_line = selection.start_line
  local result_set_index = nil
  for _, range in ipairs(stored.result_set_ranges or {}) do
    if cursor_line >= range.start_line and cursor_line <= range.end_line then
      result_set_index = range.index
      break
    end
  end

  if not result_set_index then
    -- Default to first result set
    result_set_index = 1
  end

  local cell_map = stored.cell_maps[result_set_index]
  if not cell_map then
    vim.notify("SSNS: No cell map for result set", vim.log.levels.WARN)
    return
  end

  -- Get selected cells
  local selected_cells = get_selected_cells(cell_map, selection)
  if not selected_cells or #selected_cells.rows == 0 or #selected_cells.cols == 0 then
    vim.notify("SSNS: No cells selected", vim.log.levels.WARN)
    return
  end

  local resultSet = stored.resultSets[result_set_index]
  if not resultSet then
    vim.notify("SSNS: Result set not found", vim.log.levels.WARN)
    return
  end

  -- Convert to output format
  local output = selection_to_output(resultSet, selected_cells, {
    format = format,
    include_headers = include_headers,
  })

  if output == "" then
    vim.notify("SSNS: No data to copy", vim.log.levels.WARN)
    return
  end

  -- Copy to clipboard
  vim.fn.setreg("+", output)
  vim.fn.setreg("*", output)

  local format_name = format == "tsv" and "TSV" or "CSV"
  local row_count = #selected_cells.rows
  local col_count = #selected_cells.cols
  local header_text = include_headers and " (with headers)" or ""
  vim.notify(string.format("SSNS: Copied %d rows x %d cols as %s%s", row_count, col_count, format_name, header_text), vim.log.levels.INFO)
end

---Export visual selection to file
---@param include_headers boolean? Include headers (nil = use config)
---@param filepath string? Optional file path
function QueryExport.export_selection(include_headers, filepath)
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or not stored.cell_maps then
    vim.notify("SSNS: No results with cell tracking available", vim.log.levels.WARN)
    return
  end

  -- Get visual selection bounds
  local selection = get_visual_selection_bounds()
  if not selection then
    vim.notify("SSNS: No visual selection", vim.log.levels.WARN)
    return
  end

  -- Get config
  local Config = require('nvim-ssns.config')
  local results_config = Config.get_results()
  local query_config = Config.get_query()
  local format = results_config.selection_output_format or "tsv"
  if include_headers == nil then
    include_headers = results_config.include_headers_on_selection ~= false
  end

  -- Find which result set the selection is in
  local cursor_line = selection.start_line
  local result_set_index = nil
  for _, range in ipairs(stored.result_set_ranges or {}) do
    if cursor_line >= range.start_line and cursor_line <= range.end_line then
      result_set_index = range.index
      break
    end
  end

  if not result_set_index then
    result_set_index = 1
  end

  local cell_map = stored.cell_maps[result_set_index]
  if not cell_map then
    vim.notify("SSNS: No cell map for result set", vim.log.levels.WARN)
    return
  end

  -- Get selected cells
  local selected_cells = get_selected_cells(cell_map, selection)
  if not selected_cells or #selected_cells.rows == 0 or #selected_cells.cols == 0 then
    vim.notify("SSNS: No cells selected", vim.log.levels.WARN)
    return
  end

  local resultSet = stored.resultSets[result_set_index]
  if not resultSet then
    vim.notify("SSNS: Result set not found", vim.log.levels.WARN)
    return
  end

  -- Convert to output format
  local output = selection_to_output(resultSet, selected_cells, {
    format = format,
    include_headers = include_headers,
  })

  if output == "" then
    vim.notify("SSNS: No data to export", vim.log.levels.WARN)
    return
  end

  -- Generate filename with timestamp
  local extension = format == "tsv" and ".tsv" or ".csv"
  local filename = os.date("ssns_selection_%Y%m%d_%H%M%S") .. extension

  if not filepath then
    local export_dir = query_config.export_directory

    if export_dir == "" then
      -- Empty string means prompt for location
      filepath = vim.fn.input({
        prompt = "Export selection to: ",
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
      dir = vim.fn.expand(dir)

      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end

      filepath = dir .. "/" .. filename

      if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        filepath = filepath:gsub("/", "\\")
      end
    end
  else
    filepath = vim.fn.expand(filepath)
  end

  -- Write to file
  local file, err = io.open(filepath, "w")
  if not file then
    vim.notify(string.format("SSNS: Failed to write file: %s", err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  file:write(output)
  file:close()

  local format_name = format == "tsv" and "TSV" or "CSV"
  local row_count = #selected_cells.rows
  local col_count = #selected_cells.cols
  vim.notify(string.format("SSNS: Exported %d rows x %d cols as %s to %s", row_count, col_count, format_name, filepath), vim.log.levels.INFO)

  -- Open in default application
  open_with_default_app(filepath)
end

---Get the results for a specific query buffer (for external access)
---@param query_bufnr number? The query buffer number (defaults to current context)
---@return table? results The stored results or nil
function QueryExport.get_buffer_results(query_bufnr)
  query_bufnr = query_bufnr or get_current_query_bufnr()
  return query_bufnr and UiQuery.buffer_results[query_bufnr]
end

---Clear stored results for a specific query buffer
---@param query_bufnr number? The query buffer number (defaults to current context, nil clears all)
function QueryExport.clear_buffer_results(query_bufnr)
  if query_bufnr then
    UiQuery.buffer_results[query_bufnr] = nil
  else
    UiQuery.buffer_results = {}
  end
end

-- ============================================================================
-- Async Export Functions
-- ============================================================================

-- Threshold for using chunked async write (1MB)
local ASYNC_CHUNK_THRESHOLD = 1024 * 1024

-- Threshold for showing progress indicator (100KB)
local PROGRESS_THRESHOLD = 100 * 1024

-- Last notification ID for progress updates (to replace previous notification)
local last_progress_notification = nil

---Show export progress notification
---@param bytes_written number Bytes written so far
---@param total_bytes number Total bytes to write
---@param file_name string? File being written
local function show_export_progress(bytes_written, total_bytes, file_name)
  local pct = math.floor((bytes_written / total_bytes) * 100)
  local kb_written = math.floor(bytes_written / 1024)
  local kb_total = math.floor(total_bytes / 1024)

  local msg
  if file_name then
    msg = string.format("Exporting %s: %d%% (%dKB/%dKB)", file_name, pct, kb_written, kb_total)
  else
    msg = string.format("Exporting: %d%% (%dKB/%dKB)", pct, kb_written, kb_total)
  end

  -- Use replace option if available (Neovim 0.9+)
  vim.notify(msg, vim.log.levels.INFO, {
    title = "SSNS Export",
    replace = last_progress_notification,
  })
end

---Write content to file asynchronously with optional chunking for large files
---@param filepath string The file path to write to
---@param content string The content to write
---@param opts table? Options: on_progress(bytes_written, total), on_complete(success, error)
local function write_file_async(filepath, content, opts)
  opts = opts or {}
  local FileIO = require('nvim-ssns.async.file_io')
  local content_size = #content

  if content_size <= ASYNC_CHUNK_THRESHOLD then
    -- Small file: single async write
    FileIO.write_async(filepath, content, function(result)
      if opts.on_progress then
        opts.on_progress(content_size, content_size)
      end
      if opts.on_complete then
        opts.on_complete(result.success, result.error)
      end
    end)
  else
    -- Large file: chunked async write
    local uv = vim.loop or vim.uv
    local CHUNK_SIZE = 64 * 1024  -- 64KB chunks
    local offset = 0

    uv.fs_open(filepath, "w", 438, function(err_open, fd)
      if err_open then
        vim.schedule(function()
          if opts.on_complete then
            opts.on_complete(false, "Failed to open file: " .. tostring(err_open))
          end
        end)
        return
      end

      local function write_next_chunk()
        if offset >= content_size then
          -- Done writing
          uv.fs_close(fd, function()
            vim.schedule(function()
              if opts.on_complete then
                opts.on_complete(true, nil)
              end
            end)
          end)
          return
        end

        local chunk_end = math.min(offset + CHUNK_SIZE, content_size)
        local chunk = content:sub(offset + 1, chunk_end)

        uv.fs_write(fd, chunk, offset, function(err_write, bytes_written)
          if err_write then
            uv.fs_close(fd, function()
              vim.schedule(function()
                if opts.on_complete then
                  opts.on_complete(false, "Failed to write: " .. tostring(err_write))
                end
              end)
            end)
            return
          end

          offset = offset + bytes_written

          -- Report progress
          if opts.on_progress then
            vim.schedule(function()
              opts.on_progress(offset, content_size)
            end)
          end

          -- Schedule next chunk to avoid blocking
          vim.schedule(write_next_chunk)
        end)
      end

      write_next_chunk()
    end)
  end
end

---Export results to CSV asynchronously
---@param filepath string? Optional file path (prompts if nil)
---@param opts table? Options: on_progress(bytes, total), on_complete(success, filepath, error)
function QueryExport.export_results_to_csv_async(filepath, opts)
  opts = opts or {}
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    if opts.on_complete then opts.on_complete(false, nil, "No results") end
    return
  end

  -- Determine which result set to export based on cursor position
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local result_set_index = get_result_set_at_cursor(query_bufnr, cursor_line) or 1

  local csv_content = QueryExport.results_to_csv(stored.resultSets, result_set_index)
  if csv_content == "" then
    vim.notify("SSNS: No data to export", vim.log.levels.WARN)
    if opts.on_complete then opts.on_complete(false, nil, "No data") end
    return
  end

  -- Generate filename with timestamp
  local filename
  if #stored.resultSets > 1 then
    filename = os.date("ssns_result_set_" .. result_set_index .. "_%Y%m%d_%H%M%S.csv")
  else
    filename = os.date("ssns_results_%Y%m%d_%H%M%S.csv")
  end

  -- Determine filepath if not provided
  if not filepath then
    local Config = require('nvim-ssns.config')
    local query_config = Config.get_query()
    local export_dir = query_config.export_directory

    if export_dir == "" then
      -- Sync prompt (can't be async)
      filepath = vim.fn.input({
        prompt = "Export CSV to: ",
        default = filename,
        completion = "file",
      })

      if filepath == "" then
        vim.notify("SSNS: Export cancelled", vim.log.levels.INFO)
        if opts.on_complete then opts.on_complete(false, nil, "Cancelled") end
        return
      end
      filepath = vim.fn.expand(filepath)
    else
      local dir = export_dir or get_temp_dir()
      dir = vim.fn.expand(dir)
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
      filepath = dir .. "/" .. filename
      if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        filepath = filepath:gsub("/", "\\")
      end
    end
  else
    filepath = vim.fn.expand(filepath)
  end

  -- Count rows for notification
  local row_count = 0
  if stored.resultSets[result_set_index] and stored.resultSets[result_set_index].rows then
    row_count = #stored.resultSets[result_set_index].rows
  end

  -- Write asynchronously
  write_file_async(filepath, csv_content, {
    on_progress = opts.on_progress,
    on_complete = function(success, err)
      if success then
        if #stored.resultSets > 1 then
          vim.notify(string.format("SSNS: Result set %d (%d rows) exported to %s", result_set_index, row_count, filepath), vim.log.levels.INFO)
        else
          vim.notify(string.format("SSNS: Results (%d rows) exported to %s", row_count, filepath), vim.log.levels.INFO)
        end
        open_with_default_app(filepath)
      else
        vim.notify(string.format("SSNS: Failed to export: %s", err or "unknown error"), vim.log.levels.ERROR)
      end

      if opts.on_complete then
        opts.on_complete(success, filepath, err)
      end
    end,
  })
end

---Export ALL result sets to CSV asynchronously
---@param opts table? Options: on_progress(current_set, total_sets, bytes, total_bytes), on_complete(success, filepaths, error)
function QueryExport.export_all_results_to_csv_async(opts)
  opts = opts or {}
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or #stored.resultSets == 0 then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    if opts.on_complete then opts.on_complete(false, {}, "No results") end
    return
  end

  local Config = require('nvim-ssns.config')
  local query_config = Config.get_query()
  local export_dir = query_config.export_directory

  local dir
  if export_dir == "" then
    dir = vim.fn.input({
      prompt = "Export directory: ",
      default = vim.fn.getcwd(),
      completion = "dir",
    })
    if dir == "" then
      vim.notify("SSNS: Export cancelled", vim.log.levels.INFO)
      if opts.on_complete then opts.on_complete(false, {}, "Cancelled") end
      return
    end
  else
    dir = export_dir or get_temp_dir()
  end

  dir = vim.fn.expand(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local timestamp = os.date("%Y%m%d_%H%M%S")
  local exported_files = {}
  local total_rows = 0
  local total_sets = #stored.resultSets
  local current_set = 0

  -- Process result sets sequentially
  local function export_next()
    current_set = current_set + 1
    if current_set > total_sets then
      -- All done
      if #exported_files == 0 then
        vim.notify("SSNS: No data to export", vim.log.levels.WARN)
        if opts.on_complete then opts.on_complete(false, {}, "No data") end
      else
        vim.notify(string.format("SSNS: Exported %d result sets (%d total rows) to %s", #exported_files, total_rows, dir), vim.log.levels.INFO)
        for _, file_path in ipairs(exported_files) do
          open_with_default_app(file_path)
        end
        if opts.on_complete then opts.on_complete(true, exported_files, nil) end
      end
      return
    end

    local resultSet = stored.resultSets[current_set]
    local csv_content = QueryExport.results_to_csv(stored.resultSets, current_set)

    if csv_content == "" then
      export_next()  -- Skip empty result sets
      return
    end

    local file_name = string.format("ssns_result_set_%d_%s.csv", current_set, timestamp)
    local file_path = dir .. "/" .. file_name

    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      file_path = file_path:gsub("/", "\\")
    end

    write_file_async(file_path, csv_content, {
      on_progress = function(bytes, total)
        if opts.on_progress then
          opts.on_progress(current_set, total_sets, bytes, total)
        end
      end,
      on_complete = function(success, err)
        if success then
          table.insert(exported_files, file_path)
          if resultSet.rows then
            total_rows = total_rows + #resultSet.rows
          end
        else
          vim.notify(string.format("SSNS: Failed to write %s: %s", file_name, err or "unknown"), vim.log.levels.WARN)
        end
        export_next()
      end,
    })
  end

  export_next()
end

---Export results to CSV with progress indicator for large files
---Shows progress notification for exports > 100KB
---@param filepath string? Optional file path
function QueryExport.export_with_progress(filepath)
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  -- Determine result set and generate CSV content to check size
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local result_set_index = get_result_set_at_cursor(query_bufnr, cursor_line) or 1
  local csv_content = QueryExport.results_to_csv(stored.resultSets, result_set_index)
  local content_size = #csv_content

  if content_size < PROGRESS_THRESHOLD then
    -- Small export: use sync version (fast enough)
    QueryExport.export_results_to_csv(filepath)
  else
    -- Large export: use async with progress
    local Progress = require('nvim-ssns.async.progress')
    local tracker = Progress.create(content_size, {
      message = "Exporting CSV",
      on_update = function(pct, t)
        show_export_progress(t.current, t.total, nil)
      end,
    })

    QueryExport.export_results_to_csv_async(filepath, {
      on_progress = function(bytes, total)
        tracker:set(bytes)
      end,
      on_complete = function(success, fpath, err)
        if success then
          -- Final notification handled by async function
        end
      end,
    })
  end
end

---Export all results with progress indicator
---Shows progress for each result set being exported
function QueryExport.export_all_with_progress()
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or #stored.resultSets == 0 then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  local total_sets = #stored.resultSets
  local current_set = 0

  vim.notify(string.format("SSNS: Starting export of %d result sets...", total_sets), vim.log.levels.INFO)

  QueryExport.export_all_results_to_csv_async({
    on_progress = function(set_num, total, bytes, total_bytes)
      if set_num ~= current_set then
        current_set = set_num
        vim.notify(string.format("SSNS: Exporting result set %d/%d...", set_num, total), vim.log.levels.INFO)
      end
      if total_bytes > PROGRESS_THRESHOLD then
        show_export_progress(bytes, total_bytes, string.format("set %d", set_num))
      end
    end,
    on_complete = function(success, filepaths, err)
      -- Final notification handled by async function
    end,
  })
end

-- ============================================================================
-- Excel Export Functions (requires nvim-xlsx plugin)
-- ============================================================================

---Check if nvim-xlsx plugin is available
---@return boolean available Whether the plugin is installed
---@return table? xlsx The xlsx module or nil
local function check_xlsx_available()
  local ok, xlsx = pcall(require, 'nvim-xlsx')
  return ok, ok and xlsx or nil
end

-- ============================================================================
-- Type-Based Styling Support
-- ============================================================================

---Map SQL data types to style categories
---@type table<string, string>
local TYPE_CATEGORY_MAP = {
  -- Integer types
  int = "integer",
  bigint = "integer",
  smallint = "integer",
  tinyint = "integer",
  long = "integer",
  short = "integer",
  tiny = "integer",
  longlong = "integer",
  int24 = "integer",

  -- Decimal types
  decimal = "decimal",
  numeric = "decimal",
  float = "decimal",
  real = "decimal",
  double = "decimal",
  newdecimal = "decimal",

  -- Money types (SQL Server specific)
  money = "money",
  smallmoney = "money",

  -- Date types
  date = "date",

  -- DateTime types
  datetime = "datetime",
  datetime2 = "datetime",
  smalldatetime = "datetime",
  timestamp = "datetime",

  -- Time types
  time = "time",

  -- Boolean types
  bit = "boolean",
  boolean = "boolean",
  bool = "boolean",
}

---Match a column name against a pattern (supports * wildcard)
---@param name string The column name to match
---@param pattern string The pattern to match against (supports * for prefix/suffix)
---@return boolean matched Whether the name matches the pattern
local function matches_pattern(name, pattern)
  if not name or not pattern then
    return false
  end

  -- Exact match
  if pattern == name then
    return true
  end

  -- Pattern with wildcards
  if pattern:match("%*") then
    -- Convert glob pattern to Lua pattern
    local lua_pattern = "^" .. pattern:gsub("%*", ".*"):gsub("%-", "%%-") .. "$"
    return name:match(lua_pattern) ~= nil
  end

  return false
end

---Get style category from SQL type string
---@param sql_type string? The SQL type from column metadata
---@return string? category The style category or nil
local function get_type_category(sql_type)
  if not sql_type then
    return nil
  end

  -- Normalize type string (lowercase, strip size info)
  local normalized = sql_type:lower():match("^(%w+)")
  if normalized then
    return TYPE_CATEGORY_MAP[normalized]
  end

  return nil
end

---Resolve column style by name or pattern match
---@param col_name string The column name
---@param column_styles table<string, table> Column style definitions
---@param style_presets table<string, table> Available style presets
---@return table? style The matched style or nil
local function resolve_column_style(col_name, column_styles, style_presets)
  if not column_styles or type(column_styles) ~= "table" then
    return nil
  end

  -- Try exact match first
  if column_styles[col_name] then
    local style = column_styles[col_name]
    -- Resolve preset if specified
    if style.preset and style_presets and style_presets[style.preset] then
      return vim.tbl_extend("force", style_presets[style.preset], style)
    end
    return style
  end

  -- Try pattern matches
  for pattern, style in pairs(column_styles) do
    if pattern:match("%*") and matches_pattern(col_name, pattern) then
      -- Resolve preset if specified
      if style.preset and style_presets and style_presets[style.preset] then
        return vim.tbl_extend("force", style_presets[style.preset], style)
      end
      return style
    end
  end

  return nil
end

---Evaluate a conditional rule against a value
---@param value any The cell value to evaluate
---@param rule table The conditional rule
---@param col_name string The column name for column-specific rules
---@return boolean matches Whether the value matches the condition
local function evaluate_condition(value, rule, col_name)
  if not rule then
    return false
  end

  -- Check column filter
  if rule.columns then
    local col_match = false
    for _, c in ipairs(rule.columns) do
      if c == col_name then
        col_match = true
        break
      end
    end
    if not col_match then
      return false
    end
  end

  -- Check predefined conditions
  if rule.condition then
    local cond = rule.condition
    local is_null = (value == nil or value == vim.NIL)
    local is_number = type(value) == "number"
    local is_string = type(value) == "string"

    if cond == "null" then
      return is_null
    elseif cond == "empty" then
      return is_null or (is_string and value == "")
    elseif cond == "nonempty" then
      return not is_null and not (is_string and value == "")
    elseif cond == "negative" then
      return is_number and value < 0
    elseif cond == "positive" then
      return is_number and value > 0
    elseif cond == "zero" then
      return is_number and value == 0
    end
  end

  -- Check exact match
  if rule.match ~= nil then
    if type(value) == type(rule.match) then
      return value == rule.match
    elseif type(value) == "string" then
      return value == tostring(rule.match)
    end
    return false
  end

  -- Check pattern match
  if rule.pattern then
    if type(value) == "string" then
      return value:match(rule.pattern) ~= nil
    end
    return false
  end

  return false
end

---Merge multiple style definitions (later styles override earlier)
---@param ... table Style definitions to merge
---@return table merged The merged style
local function merge_styles(...)
  local result = {}
  for _, style in ipairs({ ... }) do
    if style and type(style) == "table" then
      for k, v in pairs(style) do
        if k ~= "preset" then  -- Don't copy preset key to final style
          result[k] = v
        end
      end
    end
  end
  return result
end

---Build a column type map from result set metadata
---@param resultSet table The result set with columns metadata
---@return table<string, string> type_map Mapping of column names to type categories
local function build_column_type_map(resultSet)
  local type_map = {}
  local columns_metadata = resultSet.columns

  if columns_metadata and type(columns_metadata) == "table" then
    for col_name, col_info in pairs(columns_metadata) do
      if col_name ~= vim.NIL and col_info and col_info.type then
        local category = get_type_category(col_info.type)
        if category then
          type_map[col_name] = category
        end
      end
    end
  end

  return type_map
end

---Get ordered column names from a result set
---@param resultSet table The result set with columns metadata
---@return string[] columns Ordered column names
local function get_ordered_columns(resultSet)
  local columns = {}
  local columns_metadata = resultSet.columns

  if columns_metadata and type(columns_metadata) == "table" then
    local col_list = {}
    for col_name, col_info in pairs(columns_metadata) do
      if col_name ~= vim.NIL then
        table.insert(col_list, { name = col_name, index = col_info.index or 0 })
      end
    end

    if #col_list > 0 then
      table.sort(col_list, function(a, b) return a.index < b.index end)
      for _, col in ipairs(col_list) do
        table.insert(columns, col.name)
      end
      return columns
    end
  end

  -- Fallback: get column names from first row
  local rows = resultSet.rows or {}
  if #rows > 0 then
    for key, _ in pairs(rows[1]) do
      table.insert(columns, key)
    end
    table.sort(columns)
  end

  return columns
end

---Convert result sets to Excel workbook with SSRS-style formatting
---@param resultSets table[] Array of result sets
---@param result_set_index number? Which result set to export (nil = first, 0 = all)
---@param opts ExportConfig? Export options
---@return table? workbook The xlsx workbook or nil
---@return string? error Error message if failed
function QueryExport.results_to_xlsx(resultSets, result_set_index, opts)
  local ok, xlsx = check_xlsx_available()
  if not ok then
    return nil, "nvim-xlsx not installed"
  end

  if not resultSets or #resultSets == 0 then
    return nil, "No results to export"
  end

  opts = opts or {}
  local header_style = opts.header_style or {}
  local table_style = opts.table_style or {}
  local sheet_style = opts.sheet_style or {}
  local null_style = table_style.null_style or {}

  -- Type-based styling options
  local auto_type_formatting = opts.auto_type_formatting ~= false  -- Default: true
  local type_styles = opts.type_styles or {}
  local column_styles = opts.column_styles or {}
  local conditional_styles = opts.conditional_styles or {}
  local style_presets = opts.style_presets or {}

  local wb = xlsx.new_workbook()

  -- Style cache for dynamically created styles (keyed by serialized definition)
  local style_cache = {}

  ---Get or create a cached style from a definition
  ---@param style_def table The style definition
  ---@return any? style_id The style ID or nil
  local function get_or_create_style(style_def)
    if not style_def or vim.tbl_isempty(style_def) then
      return nil
    end

    -- Create a cache key from sorted style properties
    local key_parts = {}
    local keys = vim.tbl_keys(style_def)
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = style_def[k]
      if type(v) == "table" then
        -- Skip nested tables for cache key (shouldn't happen in our use case)
        table.insert(key_parts, k .. "=table")
      else
        table.insert(key_parts, k .. "=" .. tostring(v))
      end
    end
    local cache_key = table.concat(key_parts, "|")

    if style_cache[cache_key] then
      return style_cache[cache_key]
    end

    local style_id, _ = wb:create_style(style_def)
    if style_id then
      style_cache[cache_key] = style_id
    end
    return style_id
  end

  -- Pre-create styles for reuse across sheets
  local styles = {}

  -- Title style (if title is configured)
  if sheet_style.title then
    local title_cfg = sheet_style.title_style or {}
    local title_style_def = {
      bold = title_cfg.bold ~= false,
      italic = title_cfg.italic == true,
      font_color = title_cfg.font_color or "#000000",
      font_size = title_cfg.font_size or 14,
      halign = title_cfg.halign or "left",
    }
    if title_cfg.bg_color then
      title_style_def.bg_color = title_cfg.bg_color
    end
    if title_cfg.font_name then
      title_style_def.font_name = title_cfg.font_name
    end
    styles.title, _ = wb:create_style(title_style_def)
  end

  -- Header style
  if opts.include_headers ~= false then
    local header_style_def = {
      bold = header_style.bold ~= false,
      italic = header_style.italic == true,
      font_color = header_style.font_color or "#FFFFFF",
      bg_color = header_style.bg_color or "#4472C4",
      halign = header_style.halign or "center",
      valign = header_style.valign or "center",
      wrap_text = header_style.wrap_text == true,
    }
    if header_style.font_size then
      header_style_def.font_size = header_style.font_size
    end
    if header_style.font_name then
      header_style_def.font_name = header_style.font_name
    end
    if header_style.border ~= false then
      header_style_def.border = true
      header_style_def.border_style = header_style.border_style or "thin"
      if header_style.border_color then
        header_style_def.border_color = header_style.border_color
      end
    end
    styles.header, _ = wb:create_style(header_style_def)
  end

  -- Data row styles (odd and even for alternating rows)
  local data_style_base = {
    valign = table_style.valign or "top",
  }
  if table_style.font_color then
    data_style_base.font_color = table_style.font_color
  end
  if table_style.font_size then
    data_style_base.font_size = table_style.font_size
  end
  if table_style.font_name then
    data_style_base.font_name = table_style.font_name
  end
  if table_style.halign then
    data_style_base.halign = table_style.halign
  end
  if table_style.border ~= false then
    data_style_base.border = true
    data_style_base.border_style = table_style.border_style or "thin"
    data_style_base.border_color = table_style.border_color or "#D9D9D9"
  end

  -- Create odd row style
  local odd_style_def = vim.tbl_extend("force", {}, data_style_base)
  if table_style.odd_row_color then
    odd_style_def.bg_color = table_style.odd_row_color
  end
  styles.odd_row, _ = wb:create_style(odd_style_def)

  -- Create even row style (with alternating color if enabled)
  local even_style_def = vim.tbl_extend("force", {}, data_style_base)
  if table_style.alternating_rows ~= false and table_style.even_row_color then
    even_style_def.bg_color = table_style.even_row_color
  elseif table_style.even_row_color then
    even_style_def.bg_color = table_style.even_row_color
  end
  styles.even_row, _ = wb:create_style(even_style_def)

  -- NULL value styles (odd and even)
  local null_style_base = {
    italic = null_style.italic ~= false,
    font_color = null_style.font_color or "#808080",
    valign = table_style.valign or "top",
  }
  if table_style.border ~= false then
    null_style_base.border = true
    null_style_base.border_style = table_style.border_style or "thin"
    null_style_base.border_color = table_style.border_color or "#D9D9D9"
  end

  local null_odd_def = vim.tbl_extend("force", {}, null_style_base)
  if table_style.odd_row_color then
    null_odd_def.bg_color = table_style.odd_row_color
  end
  styles.null_odd, _ = wb:create_style(null_odd_def)

  local null_even_def = vim.tbl_extend("force", {}, null_style_base)
  if table_style.alternating_rows ~= false and table_style.even_row_color then
    null_even_def.bg_color = table_style.even_row_color
  end
  styles.null_even, _ = wb:create_style(null_even_def)

  -- Determine which result sets to export
  local sets_to_export = {}
  local export_indices = {}
  if result_set_index == 0 or result_set_index == nil then
    for i, rs in ipairs(resultSets) do
      table.insert(sets_to_export, rs)
      table.insert(export_indices, i)
    end
  else
    if resultSets[result_set_index] then
      table.insert(sets_to_export, resultSets[result_set_index])
      table.insert(export_indices, result_set_index)
    end
  end

  if #sets_to_export == 0 then
    return nil, "No result sets to export"
  end

  -- Export each result set as a sheet
  for idx, resultSet in ipairs(sets_to_export) do
    local sheet_name = string.format("Result %d", export_indices[idx])
    local sheet = wb:add_sheet(sheet_name)
    if not sheet then
      sheet = wb:add_sheet(string.format("Sheet%d", idx))
    end

    local rows = resultSet.rows or {}
    local columns = get_ordered_columns(resultSet)

    if #columns == 0 then
      goto continue_xlsx
    end

    local current_row = 1

    -- Write title if configured
    if sheet_style.title and sheet_style.title ~= "" then
      local title_cfg = sheet_style.title_style or {}
      sheet:set_cell(current_row, 1, sheet_style.title)
      if styles.title then
        sheet:set_cell_style(current_row, 1, styles.title)
      end
      -- Merge title across all columns if configured
      if title_cfg.merge_cells ~= false and #columns > 1 then
        -- Note: merge_cells API depends on nvim-xlsx implementation
        pcall(function()
          sheet:merge_cells(current_row, 1, current_row, #columns)
        end)
      end
      current_row = current_row + 1
      -- Add margin rows after title
      local margin = title_cfg.margin_bottom or 1
      current_row = current_row + margin
    end

    local header_row = current_row

    -- Write headers
    if opts.include_headers ~= false and #columns > 0 then
      for col_idx, col_name in ipairs(columns) do
        sheet:set_cell(current_row, col_idx, col_name)
        if styles.header then
          sheet:set_cell_style(current_row, col_idx, styles.header)
        end
      end
      current_row = current_row + 1
    end

    local data_start_row = current_row

    -- Build column type map for this result set
    local column_type_map = build_column_type_map(resultSet)

    -- Pre-resolve column styles for each column
    local resolved_column_styles = {}
    for _, col_name in ipairs(columns) do
      resolved_column_styles[col_name] = resolve_column_style(col_name, column_styles, style_presets)
    end

    -- Get base style definitions for merging
    local odd_row_base = vim.tbl_extend("force", {}, data_style_base)
    if table_style.odd_row_color then
      odd_row_base.bg_color = table_style.odd_row_color
    end

    local even_row_base = vim.tbl_extend("force", {}, data_style_base)
    if table_style.alternating_rows ~= false and table_style.even_row_color then
      even_row_base.bg_color = table_style.even_row_color
    elseif table_style.even_row_color then
      even_row_base.bg_color = table_style.even_row_color
    end

    -- Write data rows with type-based and conditional styling
    local null_display = table_style.null_display or ""
    for row_idx, row in ipairs(rows) do
      local is_even = (row_idx % 2 == 0)
      local base_row_style = is_even and even_row_base or odd_row_base
      local null_row_style = is_even and styles.null_even or styles.null_odd
      local excel_row = data_start_row + row_idx - 1

      for col_idx, col_name in ipairs(columns) do
        local value = row[col_name]
        local is_null = (value == nil or value == vim.NIL)

        if is_null then
          -- Write NULL display value with NULL styling
          if null_display ~= "" then
            sheet:set_cell(excel_row, col_idx, null_display)
          end
          if null_row_style then
            sheet:set_cell_style(excel_row, col_idx, null_row_style)
          end
        else
          sheet:set_cell(excel_row, col_idx, value)

          -- Build merged style: base row -> type style -> column style -> conditional styles
          local final_style = vim.tbl_extend("force", {}, base_row_style)

          -- Apply type-based style if enabled
          if auto_type_formatting then
            local type_category = column_type_map[col_name]
            if type_category and type_styles[type_category] then
              final_style = merge_styles(final_style, type_styles[type_category])
            end
          end

          -- Apply column-specific style
          local col_style = resolved_column_styles[col_name]
          if col_style then
            final_style = merge_styles(final_style, col_style)
          end

          -- Apply conditional styles (evaluated in order, all matching rules apply)
          if conditional_styles and #conditional_styles > 0 then
            for _, rule in ipairs(conditional_styles) do
              if evaluate_condition(value, rule, col_name) then
                local rule_style = rule.style
                -- Resolve preset if specified
                if rule_style and rule_style.preset and style_presets[rule_style.preset] then
                  rule_style = vim.tbl_extend("force", style_presets[rule_style.preset], rule_style)
                end
                if rule_style then
                  final_style = merge_styles(final_style, rule_style)
                end
              end
            end
          end

          -- Get or create the merged style and apply it
          local cell_style = get_or_create_style(final_style)
          if cell_style then
            sheet:set_cell_style(excel_row, col_idx, cell_style)
          end
        end
      end
    end

    -- Apply sheet-level settings
    -- Freeze header row
    if sheet_style.freeze_header ~= false and opts.include_headers ~= false then
      pcall(function()
        sheet:freeze_panes(header_row, 0)
      end)
    end

    -- Enable auto-filter on headers
    if sheet_style.auto_filter ~= false and opts.include_headers ~= false and #rows > 0 then
      pcall(function()
        local last_row = data_start_row + #rows - 1
        sheet:set_auto_filter(header_row, 1, last_row, #columns)
      end)
    end

    -- Set page orientation for printing
    if sheet_style.orientation then
      pcall(function()
        sheet:set_orientation(sheet_style.orientation)
      end)
    end

    -- Configure print settings
    if sheet_style.fit_to_page or sheet_style.print_gridlines or sheet_style.print_headers then
      pcall(function()
        local print_settings = {}
        if sheet_style.fit_to_page then
          print_settings.fitToWidth = 1
          print_settings.fitToHeight = 0  -- 0 = as many pages as needed
        end
        if sheet_style.print_gridlines then
          print_settings.gridLines = true
        end
        if sheet_style.print_headers then
          print_settings.headings = true
        end
        sheet:set_print_settings(print_settings)
      end)
    end

    -- Auto-fit column widths
    if table_style.auto_fit_columns ~= false then
      local min_width = table_style.min_col_width or 8
      local max_width = table_style.max_col_width or 50

      for col_idx, col_name in ipairs(columns) do
        -- Calculate width based on header and data
        local width = #tostring(col_name)
        for _, row in ipairs(rows) do
          local value = row[col_name]
          if value ~= nil and value ~= vim.NIL then
            local val_len = #tostring(value)
            if val_len > width then
              width = val_len
            end
          end
        end
        -- Apply min/max constraints
        width = math.max(min_width, math.min(max_width, width + 2))  -- +2 for padding
        pcall(function()
          sheet:set_column_width(col_idx, width)
        end)
      end
    end

    ::continue_xlsx::
  end

  return wb, nil
end

---Export results to Excel file and open in default application
---Exports only the result set under the cursor
---@param filepath string? Optional file path (uses config export_directory if not provided)
function QueryExport.export_results_to_xlsx(filepath)
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  -- Check if xlsx is available
  local xlsx_ok = check_xlsx_available()
  if not xlsx_ok then
    vim.notify("SSNS: nvim-xlsx not installed, cannot export to Excel", vim.log.levels.ERROR)
    return
  end

  -- Get export configuration
  local Config = require('nvim-ssns.config')
  local query_config = Config.get_query()
  local export_config = query_config.export or {}

  -- Determine which result set to export based on cursor position
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local result_set_index = get_result_set_at_cursor(query_bufnr, cursor_line)

  if not result_set_index then
    result_set_index = 1
  end

  -- Create workbook with single result set
  local wb, err = QueryExport.results_to_xlsx(stored.resultSets, result_set_index, export_config)
  if not wb then
    vim.notify(string.format("SSNS: Failed to create Excel file: %s", err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Generate filename with timestamp
  local filename
  if #stored.resultSets > 1 then
    filename = os.date("ssns_result_set_" .. result_set_index .. "_%Y%m%d_%H%M%S.xlsx")
  else
    filename = os.date("ssns_results_%Y%m%d_%H%M%S.xlsx")
  end

  if not filepath then
    local export_dir = query_config.export_directory

    if export_dir == "" then
      -- Empty string means prompt for location
      filepath = vim.fn.input({
        prompt = "Export Excel to: ",
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
      dir = vim.fn.expand(dir)

      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end

      filepath = dir .. "/" .. filename

      if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
        filepath = filepath:gsub("/", "\\")
      end
    end
  else
    filepath = vim.fn.expand(filepath)
  end

  -- Ensure .xlsx extension
  if not filepath:match("%.xlsx$") then
    filepath = filepath .. ".xlsx"
  end

  -- Save workbook
  local save_ok, save_err = wb:save(filepath)
  if not save_ok then
    vim.notify(string.format("SSNS: Failed to save Excel file: %s", save_err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Count rows
  local row_count = 0
  if stored.resultSets[result_set_index] and stored.resultSets[result_set_index].rows then
    row_count = #stored.resultSets[result_set_index].rows
  end

  if #stored.resultSets > 1 then
    vim.notify(string.format("SSNS: Result set %d (%d rows) exported to %s", result_set_index, row_count, filepath), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Results (%d rows) exported to %s", row_count, filepath), vim.log.levels.INFO)
  end

  open_with_default_app(filepath)
end

---Export ALL result sets to Excel
---Uses config multi_result_mode to determine sheets vs workbooks
function QueryExport.export_all_results_to_xlsx()
  local query_bufnr = get_current_query_bufnr()
  local stored = query_bufnr and UiQuery.buffer_results[query_bufnr]

  if not stored or not stored.resultSets or #stored.resultSets == 0 then
    vim.notify("SSNS: No results to export", vim.log.levels.WARN)
    return
  end

  -- Check if xlsx is available
  local xlsx_ok = check_xlsx_available()
  if not xlsx_ok then
    vim.notify("SSNS: nvim-xlsx not installed, cannot export to Excel", vim.log.levels.ERROR)
    return
  end

  -- Get export configuration
  local Config = require('nvim-ssns.config')
  local query_config = Config.get_query()
  local export_config = query_config.export or {}
  local mode = export_config.multi_result_mode or "sheets"
  local export_dir = query_config.export_directory

  -- Determine export directory
  local dir
  if export_dir == "" then
    dir = vim.fn.input({
      prompt = "Export directory: ",
      default = vim.fn.getcwd(),
      completion = "dir",
    })

    if dir == "" then
      vim.notify("SSNS: Export cancelled", vim.log.levels.INFO)
      return
    end
  else
    dir = export_dir or get_temp_dir()
  end

  dir = vim.fn.expand(dir)

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local timestamp = os.date("%Y%m%d_%H%M%S")
  local total_rows = 0

  if mode == "sheets" then
    -- Single workbook with multiple sheets
    local wb, err = QueryExport.results_to_xlsx(stored.resultSets, 0, export_config)
    if not wb then
      vim.notify(string.format("SSNS: Failed to create Excel file: %s", err or "unknown error"), vim.log.levels.ERROR)
      return
    end

    local filepath = dir .. "/ssns_results_" .. timestamp .. ".xlsx"
    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      filepath = filepath:gsub("/", "\\")
    end

    local save_ok, save_err = wb:save(filepath)
    if not save_ok then
      vim.notify(string.format("SSNS: Failed to save Excel file: %s", save_err or "unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Count total rows
    for _, rs in ipairs(stored.resultSets) do
      if rs.rows then
        total_rows = total_rows + #rs.rows
      end
    end

    vim.notify(string.format("SSNS: Exported %d result sets (%d total rows) to %s", #stored.resultSets, total_rows, filepath), vim.log.levels.INFO)
    open_with_default_app(filepath)
  else
    -- Separate workbooks per result set
    local exported_files = {}

    for i, resultSet in ipairs(stored.resultSets) do
      local wb, err = QueryExport.results_to_xlsx(stored.resultSets, i, export_config)
      if wb then
        local filepath = string.format("%s/ssns_result_set_%d_%s.xlsx", dir, i, timestamp)
        if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
          filepath = filepath:gsub("/", "\\")
        end

        local save_ok, save_err = wb:save(filepath)
        if save_ok then
          table.insert(exported_files, filepath)
          if resultSet.rows then
            total_rows = total_rows + #resultSet.rows
          end
        else
          vim.notify(string.format("SSNS: Failed to write result set %d: %s", i, save_err or "unknown"), vim.log.levels.WARN)
        end
      else
        vim.notify(string.format("SSNS: Failed to create result set %d: %s", i, err or "unknown"), vim.log.levels.WARN)
      end
    end

    if #exported_files == 0 then
      vim.notify("SSNS: No data to export", vim.log.levels.WARN)
      return
    end

    vim.notify(string.format("SSNS: Exported %d result sets (%d total rows) to %s", #exported_files, total_rows, dir), vim.log.levels.INFO)

    for _, file_path in ipairs(exported_files) do
      open_with_default_app(file_path)
    end
  end
end

-- ============================================================================
-- Smart Export Functions (respect config, fallback to CSV)
-- ============================================================================

---Smart export: uses configured format with fallback to CSV
---@param filepath string? Optional file path
function QueryExport.export_results(filepath)
  local Config = require('nvim-ssns.config')
  local export_config = Config.get_query().export or {}

  if export_config.format == "excel" then
    local xlsx_ok = check_xlsx_available()
    if xlsx_ok then
      return QueryExport.export_results_to_xlsx(filepath)
    else
      vim.notify("SSNS: nvim-xlsx not installed, falling back to CSV", vim.log.levels.WARN)
    end
  end

  return QueryExport.export_results_to_csv(filepath)
end

---Smart export all: uses configured format with fallback to CSV
function QueryExport.export_all_results()
  local Config = require('nvim-ssns.config')
  local export_config = Config.get_query().export or {}

  if export_config.format == "excel" then
    local xlsx_ok = check_xlsx_available()
    if xlsx_ok then
      return QueryExport.export_all_results_to_xlsx()
    else
      vim.notify("SSNS: nvim-xlsx not installed, falling back to CSV", vim.log.levels.WARN)
    end
  end

  return QueryExport.export_all_results_to_csv()
end

---Check if Excel export is available
---@return boolean available
function QueryExport.is_xlsx_available()
  local ok = check_xlsx_available()
  return ok
end

---Initialize the export module with parent reference
---@param parent UiQuery The parent UiQuery module
function QueryExport._init(parent)
  UiQuery = parent
end

return QueryExport
