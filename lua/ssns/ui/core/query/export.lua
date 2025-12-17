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

  local Config = require('ssns.config')
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

---Initialize the export module with parent reference
---@param parent UiQuery The parent UiQuery module
function QueryExport._init(parent)
  UiQuery = parent
end

return QueryExport
