---@class ViewDebugLog
---View debug log in a floating window
---Displays the ssns_debug.log contents with filtering options
---@module ssns.features.view_debug_log
local ViewDebugLog = {}

local UiFloat = require('ssns.ui.float')
local Debug = require('ssns.debug')

-- Store reference to current floating window for cleanup
local current_float = nil

-- Current filter state
local current_filter = nil
local max_lines = 200

---Close the current floating window
function ViewDebugLog.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
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
  -- Close any existing float
  ViewDebugLog.close_current_float()

  current_filter = filter
  local log_path = Debug.get_log_path()

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Debug Log Viewer")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Log file info
  table.insert(display_lines, "Log File")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Path: %s", log_path))

  -- Check file size
  local f = io.open(log_path, 'r')
  if f then
    local size = f:seek("end")
    f:close()
    table.insert(display_lines, string.format("  Size: %d bytes", size or 0))
  end
  table.insert(display_lines, "")

  -- Component counts
  local counts = count_by_component()
  if next(counts) then
    table.insert(display_lines, "Log Entries by Component")
    table.insert(display_lines, string.rep("-", 30))

    local sorted_components = {}
    for comp in pairs(counts) do
      table.insert(sorted_components, comp)
    end
    table.sort(sorted_components)

    for _, comp in ipairs(sorted_components) do
      table.insert(display_lines, string.format("  [%s]: %d", comp, counts[comp]))
    end
    table.insert(display_lines, "")
  end

  -- Filter info
  if filter then
    table.insert(display_lines, string.format("Filter: \"%s\"", filter))
    table.insert(display_lines, "")
  end

  -- Log content
  table.insert(display_lines, "Log Content (Last " .. max_lines .. " lines)")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "")

  local log_lines, total = read_log_file(filter)
  if filter then
    table.insert(display_lines, string.format("(Showing %d of %d matching lines)", #log_lines, total))
    table.insert(display_lines, "")
  end

  for _, line in ipairs(log_lines) do
    table.insert(display_lines, line)
  end

  if #log_lines == 0 then
    table.insert(display_lines, "(No log entries" .. (filter and " matching filter" or "") .. ")")
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Debug Log" .. (filter and (" [" .. filter .. "]") or ""),
    border = "rounded",
    filetype = "log",
    min_width = 80,
    max_width = 140,
    max_height = 45,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh with same filter
        ViewDebugLog.view_log(current_filter)
      end,
      ['c'] = function()
        -- Clear filter
        ViewDebugLog.view_log(nil)
      end,
      ['f'] = function()
        -- Prompt for filter
        vim.ui.input({ prompt = "Filter: " }, function(input)
          if input and input ~= "" then
            ViewDebugLog.view_log(input)
          end
        end)
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
    },
    footer = "q: close | r: refresh | f: filter | c: clear filter | C: clear log | 1-4: quick filters",
  })
end

return ViewDebugLog
