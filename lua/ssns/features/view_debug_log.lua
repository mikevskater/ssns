---@class ViewDebugLog
---View debug log in a floating window
---Displays the ssns_debug.log contents with filtering options
---@module ssns.features.view_debug_log
local ViewDebugLog = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
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

  -- Build styled content
  local cb = ContentBuilder.new()

  cb:header("Debug Log Viewer")
  cb:separator()
  cb:blank()

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

  -- Create floating window with styled content
  current_float = UiFloat.create_styled(cb, {
    title = "Debug Log" .. (filter and (" [" .. filter .. "]") or ""),
    border = "rounded",
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
          local cb = filter_win:get_content_builder()
          cb:line("")
          cb:labeled_input("filter", "  Filter", {
            value = current_filter or "",
            placeholder = "(enter filter text)",
            width = 35,  -- Default width, expands for longer filters
          })
          cb:line("")
          cb:line("  <Enter>=Apply | <Esc>=Cancel", "SsnsUiHint")
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
    },
    footer = "q: close | r: refresh | f: filter | c: clear filter | C: clear log | 1-4: quick filters",
  })
end

return ViewDebugLog

