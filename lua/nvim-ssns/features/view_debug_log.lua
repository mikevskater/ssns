---@class ViewDebugLog
---View debug log in a floating window
---Displays the ssns_debug.log contents with filtering options
---@module ssns.features.view_debug_log
local ViewDebugLog = {}

local BaseViewer = require('nvim-ssns.features.base_viewer')
local UiFloat = require('nvim-float.window')
local Debug = require('nvim-ssns.debug')
local FileIO = require('nvim-ssns.async.file_io')

-- Current filter state
local current_filter = nil
local max_lines = 200

-- Large file threshold (1MB) - show warning and offer tail
local LARGE_FILE_THRESHOLD = 1024 * 1024

-- Cached log data for async loading
local cached_log_data = nil

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Debug Log",
  min_width = 80,
  max_width = 140,
  max_height = 45,
  footer = "q: close | r: refresh | f: filter | c: clear filter | C: clear log | 1-4: quick filters",
})

---Close the current floating window
function ViewDebugLog.close_current_float()
  viewer:close()
end

---Read log file and return lines
---@param filter string? Optional filter pattern
---@return string[] lines
---@return number total_lines
local function read_log_file(filter)
  local log_path = Debug.get_log_path()
  local lines = {}
  local total_lines = 0

  local f = io.open(log_path, 'r')
  if not f then
    return { "(Log file not found: " .. log_path .. ")" }, 0
  end

  -- Read all lines
  local all_lines = {}
  for line in f:lines() do
    total_lines = total_lines + 1
    if not filter or line:lower():find(filter:lower(), 1, true) then
      table.insert(all_lines, line)
    end
  end
  f:close()

  -- Return last N lines (most recent)
  local start_idx = math.max(1, #all_lines - max_lines + 1)
  for i = start_idx, #all_lines do
    table.insert(lines, all_lines[i])
  end

  return lines, total_lines
end

---Read log file asynchronously
---@param filter string? Optional filter pattern
---@param callback fun(lines: string[], total_lines: number, file_size: number)
local function read_log_file_async(filter, callback)
  local log_path = Debug.get_log_path()

  -- First get file stats
  FileIO.stat_async(log_path, function(stat, err)
    if err or not stat then
      vim.schedule(function()
        callback({ "(Log file not found: " .. log_path .. ")" }, 0, 0)
      end)
      return
    end

    local file_size = stat.size or 0

    -- Read file content
    FileIO.read_async(log_path, function(result)
      if not result.success then
        vim.schedule(function()
          callback({ "(Failed to read log file)" }, 0, file_size)
        end)
        return
      end

      -- Process lines
      local all_lines = vim.split(result.data or "", "\n", { plain = true })
      local total_lines = #all_lines
      local filtered_lines = {}

      -- Apply filter if specified
      local filter_lower = filter and filter:lower()
      for _, line in ipairs(all_lines) do
        if not filter or line:lower():find(filter_lower, 1, true) then
          table.insert(filtered_lines, line)
        end
      end

      -- Return last N lines (most recent)
      local lines = {}
      local start_idx = math.max(1, #filtered_lines - max_lines + 1)
      for i = start_idx, #filtered_lines do
        table.insert(lines, filtered_lines[i])
      end

      vim.schedule(function()
        callback(lines, total_lines, file_size)
      end)
    end)
  end)
end

---Read only the tail of a large log file asynchronously
---@param num_bytes number Number of bytes to read from end
---@param filter string? Optional filter pattern
---@param callback fun(lines: string[], total_lines: number, file_size: number)
local function read_log_tail_async(num_bytes, filter, callback)
  local log_path = Debug.get_log_path()
  local uv = vim.loop or vim.uv

  FileIO.stat_async(log_path, function(stat, err)
    if err or not stat then
      vim.schedule(function()
        callback({ "(Log file not found)" }, 0, 0)
      end)
      return
    end

    local file_size = stat.size or 0
    local read_offset = math.max(0, file_size - num_bytes)
    local read_size = math.min(num_bytes, file_size)

    -- Open and read from offset
    uv.fs_open(log_path, "r", 438, function(open_err, fd)
      if open_err or not fd then
        vim.schedule(function()
          callback({ "(Failed to open log file)" }, 0, file_size)
        end)
        return
      end

      uv.fs_read(fd, read_size, read_offset, function(read_err, data)
        uv.fs_close(fd, function() end)

        if read_err or not data then
          vim.schedule(function()
            callback({ "(Failed to read log file)" }, 0, file_size)
          end)
          return
        end

        -- Process lines (skip first partial line if we didn't start at 0)
        local all_lines = vim.split(data, "\n", { plain = true })
        if read_offset > 0 and #all_lines > 0 then
          table.remove(all_lines, 1) -- Remove potentially incomplete first line
        end

        local filtered_lines = {}
        local filter_lower = filter and filter:lower()
        for _, line in ipairs(all_lines) do
          if line ~= "" and (not filter or line:lower():find(filter_lower, 1, true)) then
            table.insert(filtered_lines, line)
          end
        end

        -- Return last N lines
        local lines = {}
        local start_idx = math.max(1, #filtered_lines - max_lines + 1)
        for i = start_idx, #filtered_lines do
          table.insert(lines, filtered_lines[i])
        end

        vim.schedule(function()
          -- Estimate total lines (rough approximation)
          local avg_line_len = read_size / math.max(1, #all_lines)
          local estimated_total = math.floor(file_size / math.max(1, avg_line_len))
          callback(lines, estimated_total, file_size)
        end)
      end)
    end)
  end)
end

---Count log entries by component
---@return table<string, number> counts
local function count_by_component()
  local log_path = Debug.get_log_path()
  local counts = {}

  local f = io.open(log_path, 'r')
  if not f then
    return counts
  end

  for line in f:lines() do
    -- Extract component from [component] pattern
    local component = line:match("%[([%w_]+)%]")
    if component then
      counts[component] = (counts[component] or 0) + 1
    end
  end
  f:close()

  return counts
end

---View debug log
---@param filter string? Optional filter pattern
function ViewDebugLog.view_log(filter)
  current_filter = filter

  -- Update title based on filter
  viewer.title = "Debug Log" .. (filter and (" [" .. filter .. "]") or "")

  -- Set refresh callback and custom keymaps
  viewer.on_refresh = function() ViewDebugLog.view_log(current_filter) end
  viewer:set_keymaps({
    ['c'] = function()
      -- Clear filter
      ViewDebugLog.view_log(nil)
    end,
    ['f'] = function()
      -- Show filter input dialog
      local filter_win = UiFloat.create({
        title = "Filter Log",
        width = 50,
        height = 7,
        center = true,
        content_builder = true,
        enable_inputs = true,
        zindex = UiFloat.ZINDEX.OVERLAY,
      })

      if filter_win then
        local fcb = filter_win:get_content_builder()
        fcb:line("")
        fcb:labeled_input("filter", "  Filter", {
          value = current_filter or "",
          placeholder = "(enter filter text)",
          width = 35,
        })
        fcb:line("")
        fcb:styled("  <Enter>=Apply | <Esc>=Cancel", "NvimFloatHint")
        filter_win:render()

        local function apply_filter()
          local input = filter_win:get_input_value("filter")
          filter_win:close()
          if input and input ~= "" then
            ViewDebugLog.view_log(input)
          end
        end

        vim.keymap.set("n", "<CR>", function()
          filter_win:enter_input()
        end, { buffer = filter_win.buf, nowait = true })

        vim.keymap.set("n", "<Esc>", function()
          filter_win:close()
        end, { buffer = filter_win.buf, nowait = true })

        vim.keymap.set("n", "q", function()
          filter_win:close()
        end, { buffer = filter_win.buf, nowait = true })

        filter_win:on_input_submit(apply_filter)
      end
    end,
    ['C'] = function()
      -- Clear log file
      local path = Debug.get_log_path()
      local file = io.open(path, 'w')
      if file then
        file:write("=== SSNS Debug Log (Cleared) ===\n")
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
        file:close()
        vim.notify("SSNS: Debug log cleared", vim.log.levels.INFO)
        ViewDebugLog.view_log(current_filter)
      end
    end,
    -- Filter shortcuts
    ['1'] = function() ViewDebugLog.view_log("statement_context") end,
    ['2'] = function() ViewDebugLog.view_log("completion") end,
    ['3'] = function() ViewDebugLog.view_log("USAGE") end,
    ['4'] = function() ViewDebugLog.view_log("ERROR") end,
  })

  local log_path = Debug.get_log_path()

  -- Show content (no JSON needed for log viewer)
  viewer:show(function(cb)
    BaseViewer.add_header(cb, "Debug Log Viewer")

    -- Log file info
    cb:section("Log File")
    cb:label_value("  Path", log_path)

    -- Check file size
    local f = io.open(log_path, 'r')
    if f then
      local size = f:seek("end")
      f:close()
      cb:label_value("  Size", string.format("%d bytes", size or 0))
    end
    cb:blank()

    -- Component counts
    local counts = count_by_component()
    if next(counts) then
      cb:section("Log Entries by Component")

      local sorted_components = {}
      for comp in pairs(counts) do
        table.insert(sorted_components, comp)
      end
      table.sort(sorted_components)

      for _, comp in ipairs(sorted_components) do
        cb:spans({
          { text = "  [", style = "muted" },
          { text = comp, style = "label" },
          { text = "]: ", style = "muted" },
          { text = tostring(counts[comp]), style = "number" },
        })
      end
      cb:blank()
    end

    -- Filter info
    if filter then
      cb:spans({
        { text = "Filter: ", style = "label" },
        { text = "\"" .. filter .. "\"", style = "value" },
      })
      cb:blank()
    end

    -- Log content
    cb:section("Log Content (Last " .. max_lines .. " lines)")
    cb:blank()

    local log_lines, total = read_log_file(filter)
    if filter then
      cb:spans({
        { text = "(Showing ", style = "muted" },
        { text = tostring(#log_lines), style = "number" },
        { text = " of ", style = "muted" },
        { text = tostring(total), style = "number" },
        { text = " matching lines)", style = "muted" },
      })
      cb:blank()
    end

    for _, line in ipairs(log_lines) do
      -- Color log lines based on content
      if line:find("ERROR") or line:find("error") then
        cb:styled(line, "error")
      elseif line:find("WARN") or line:find("warn") then
        cb:styled(line, "warning")
      elseif line:find("DEBUG") or line:find("debug") then
        cb:styled(line, "muted")
      else
        cb:styled(line, "text")
      end
    end

    if #log_lines == 0 then
      cb:styled("(No log entries" .. (filter and " matching filter" or "") .. ")", "muted")
    end
  end)
end

---View debug log with async loading for large files
---Checks file size first and offers to tail large files
---@param filter string? Optional filter pattern
function ViewDebugLog.view_log_async(filter)
  local log_path = Debug.get_log_path()

  -- Check file size first
  FileIO.stat_async(log_path, function(stat, err)
    if err or not stat then
      vim.notify("SSNS: Log file not found: " .. log_path, vim.log.levels.WARN)
      return
    end

    local file_size = stat.size or 0

    if file_size > LARGE_FILE_THRESHOLD then
      -- Large file - ask user what to do
      vim.schedule(function()
        local size_mb = string.format("%.1f", file_size / (1024 * 1024))
        local choice = vim.fn.confirm(
          string.format("Log file is large (%s MB). How would you like to view it?", size_mb),
          "&Tail (last 500KB)\n&Full (may be slow)\n&Cancel",
          1
        )

        if choice == 1 then
          -- Tail mode - read last 500KB
          read_log_tail_async(500 * 1024, filter, function(lines, total, fsize)
            cached_log_data = { lines = lines, total = total, file_size = fsize, is_tail = true }
            ViewDebugLog._show_cached_log(filter)
          end)
        elseif choice == 2 then
          -- Full read (async)
          vim.notify("SSNS: Loading full log file...", vim.log.levels.INFO)
          read_log_file_async(filter, function(lines, total, fsize)
            cached_log_data = { lines = lines, total = total, file_size = fsize, is_tail = false }
            ViewDebugLog._show_cached_log(filter)
          end)
        end
        -- Choice 3 = Cancel, do nothing
      end)
    else
      -- Small file - read async and show
      read_log_file_async(filter, function(lines, total, fsize)
        cached_log_data = { lines = lines, total = total, file_size = fsize, is_tail = false }
        ViewDebugLog._show_cached_log(filter)
      end)
    end
  end)
end

---Internal: Show the cached log data in the viewer
---@param filter string? Current filter
function ViewDebugLog._show_cached_log(filter)
  if not cached_log_data then
    vim.notify("SSNS: No log data loaded", vim.log.levels.WARN)
    return
  end

  current_filter = filter
  local log_path = Debug.get_log_path()

  -- Update title based on filter and tail mode
  local title = "Debug Log"
  if cached_log_data.is_tail then
    title = title .. " (Tail)"
  end
  if filter then
    title = title .. " [" .. filter .. "]"
  end
  viewer.title = title

  -- Set refresh callback
  viewer.on_refresh = function() ViewDebugLog.view_log_async(current_filter) end

  -- Set keymaps (same as sync version)
  viewer:set_keymaps({
    ['c'] = function() ViewDebugLog.view_log_async(nil) end,
    ['f'] = function()
      local filter_win = UiFloat.create({
        title = "Filter Log",
        width = 50,
        height = 7,
        center = true,
        content_builder = true,
        enable_inputs = true,
        zindex = UiFloat.ZINDEX.OVERLAY,
      })

      if filter_win then
        local fcb = filter_win:get_content_builder()
        fcb:line("")
        fcb:labeled_input("filter", "  Filter", {
          value = current_filter or "",
          placeholder = "(enter filter text)",
          width = 35,
        })
        fcb:line("")
        fcb:styled("  <Enter>=Apply | <Esc>=Cancel", "NvimFloatHint")
        filter_win:render()

        local function apply_filter()
          local input = filter_win:get_input_value("filter")
          filter_win:close()
          if input and input ~= "" then
            ViewDebugLog.view_log_async(input)
          end
        end

        vim.keymap.set("n", "<CR>", function() filter_win:enter_input() end, { buffer = filter_win.buf, nowait = true })
        vim.keymap.set("n", "<Esc>", function() filter_win:close() end, { buffer = filter_win.buf, nowait = true })
        vim.keymap.set("n", "q", function() filter_win:close() end, { buffer = filter_win.buf, nowait = true })
        filter_win:on_input_submit(apply_filter)
      end
    end,
    ['C'] = function()
      local path = Debug.get_log_path()
      local file = io.open(path, 'w')
      if file then
        file:write("=== SSNS Debug Log (Cleared) ===\n")
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
        file:close()
        vim.notify("SSNS: Debug log cleared", vim.log.levels.INFO)
        ViewDebugLog.view_log_async(current_filter)
      end
    end,
    ['1'] = function() ViewDebugLog.view_log_async("statement_context") end,
    ['2'] = function() ViewDebugLog.view_log_async("completion") end,
    ['3'] = function() ViewDebugLog.view_log_async("USAGE") end,
    ['4'] = function() ViewDebugLog.view_log_async("ERROR") end,
  })

  -- Show viewer with cached data
  viewer:show(function(cb)
    BaseViewer.add_header(cb, "Debug Log Viewer")

    cb:section("Log File")
    cb:label_value("  Path", log_path)
    cb:label_value("  Size", string.format("%d bytes (%.1f KB)", cached_log_data.file_size, cached_log_data.file_size / 1024))
    if cached_log_data.is_tail then
      cb:styled("  (Showing tail of file - last 500KB)", "warning")
    end
    cb:blank()

    if filter then
      cb:spans({
        { text = "Filter: ", style = "label" },
        { text = "\"" .. filter .. "\"", style = "value" },
      })
      cb:blank()
    end

    cb:section("Log Content (Last " .. max_lines .. " lines)")
    cb:blank()

    cb:spans({
      { text = "(Showing ", style = "muted" },
      { text = tostring(#cached_log_data.lines), style = "number" },
      { text = " of ~", style = "muted" },
      { text = tostring(cached_log_data.total), style = "number" },
      { text = " total lines)", style = "muted" },
    })
    cb:blank()

    for _, line in ipairs(cached_log_data.lines) do
      if line:find("ERROR") or line:find("error") then
        cb:styled(line, "error")
      elseif line:find("WARN") or line:find("warn") then
        cb:styled(line, "warning")
      elseif line:find("DEBUG") or line:find("debug") then
        cb:styled(line, "muted")
      else
        cb:styled(line, "text")
      end
    end

    if #cached_log_data.lines == 0 then
      cb:styled("(No log entries" .. (filter and " matching filter" or "") .. ")", "muted")
    end
  end)
end

---Get log file size asynchronously
---@param callback fun(size: number?, error: string?)
function ViewDebugLog.get_log_size_async(callback)
  local log_path = Debug.get_log_path()
  FileIO.stat_async(log_path, function(stat, err)
    if err or not stat then
      callback(nil, err or "File not found")
    else
      callback(stat.size, nil)
    end
  end)
end

return ViewDebugLog

