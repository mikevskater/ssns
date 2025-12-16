---Base viewer class for SSNS floating windows
---Provides common patterns for debug/inspection floating windows
---@module ssns.features.base_viewer
---@class BaseViewer

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local JsonUtils = require('ssns.utils.json')

local M = {}

---@class ViewerInstance
---@field current_float table? Reference to current floating window
---@field title string Window title
---@field build_content function Function to build ContentBuilder content
---@field opts ViewerOpts? Optional viewer configuration

---@class ViewerOpts
---@field title string? Window title
---@field min_width number? Minimum window width (default: 60)
---@field max_width number? Maximum window width (default: 110)
---@field max_height number? Maximum window height
---@field wrap boolean? Whether to wrap text (default: false)
---@field border string? Border style (default: "rounded")
---@field footer string? Footer text (default: "q: close | r: refresh")
---@field on_refresh function? Custom refresh callback
---@field keymaps table<string, function>? Additional keymaps to add

---Create a new viewer instance
---@param opts ViewerOpts Configuration options
---@return ViewerInstance
function M.create(opts)
  opts = opts or {}

  local viewer = {
    current_float = nil,
    title = opts.title or "Viewer",
    min_width = opts.min_width or 60,
    max_width = opts.max_width or 110,
    max_height = opts.max_height,
    wrap = opts.wrap or false,
    border = opts.border or "rounded",
    footer = opts.footer or "q: close | r: refresh",
    on_refresh = opts.on_refresh,
    extra_keymaps = opts.keymaps or {},
  }

  ---Close the current floating window
  function viewer:close()
    if self.current_float then
      if self.current_float.close then
        pcall(function() self.current_float:close() end)
      end
    end
    self.current_float = nil
  end

  ---Set additional keymaps (call before show)
  ---@param keymaps table<string, function> Keymap table
  function viewer:set_keymaps(keymaps)
    self.extra_keymaps = keymaps or {}
  end

  ---Add a single keymap (call before show)
  ---@param key string Key to map
  ---@param fn function Function to call
  function viewer:add_keymap(key, fn)
    self.extra_keymaps[key] = fn
  end

  ---Show the viewer with content from a build function
  ---@param build_fn function(cb: ContentBuilder): table? Function that builds content, optionally returns JSON data
  function viewer:show(build_fn)
    -- Close any existing float
    self:close()

    -- Create ContentBuilder
    local cb = ContentBuilder.new()

    -- Let the caller build content
    local json_data = build_fn(cb)

    -- Create floating window with refresh keymap
    local refresh_fn = self.on_refresh or function()
      self:show(build_fn)
    end

    -- Merge keymaps: default 'r' for refresh + any extra keymaps
    local keymaps = { ['r'] = refresh_fn }
    for key, fn in pairs(self.extra_keymaps) do
      keymaps[key] = fn
    end

    local float_opts = {
      title = self.title,
      border = self.border,
      min_width = self.min_width,
      max_width = self.max_width,
      wrap = self.wrap,
      keymaps = keymaps,
      footer = self.footer,
    }

    if self.max_height then
      float_opts.max_height = self.max_height
    end

    self.current_float = UiFloat.create_styled(cb, float_opts)

    return self.current_float
  end

  ---Show viewer with automatic JSON section
  ---@param build_fn function(cb: ContentBuilder): table Function that builds content and returns data for JSON
  ---@param json_title string? Title for JSON section (default: "JSON Output")
  function viewer:show_with_json(build_fn, json_title)
    json_title = json_title or "JSON Output"

    return self:show(function(cb)
      -- Let caller build main content
      local json_data = build_fn(cb)

      -- Add JSON section if data provided
      if json_data then
        cb:blank()
        cb:header(json_title)
        cb:separator("=", 50)
        cb:blank()

        local json_lines = JsonUtils.prettify_lines(json_data)
        for _, line in ipairs(json_lines) do
          cb:line(line)
        end
      end

      return json_data
    end)
  end

  return viewer
end

---Helper: Get current buffer info (commonly needed by viewers)
---@return table info { bufnr, lines, text, cursor, line_num, col, line_text }
function M.get_buffer_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2] + 1  -- Convert to 1-indexed

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  local line_text = current_lines[1] or ""

  return {
    bufnr = bufnr,
    lines = lines,
    text = text,
    cursor = cursor,
    line_num = line_num,
    col = col,
    line_text = line_text,
  }
end

---Helper: Add a standard header section to content
---@param cb ContentBuilder The content builder
---@param title string Header title
function M.add_header(cb, title)
  cb:header(title)
  cb:separator("=", 50)
  cb:blank()
end

---Helper: Add cursor position section (commonly needed)
---@param cb ContentBuilder The content builder
---@param info table Buffer info from get_buffer_info()
function M.add_cursor_section(cb, info)
  cb:section("Cursor Position")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Buffer: ", style = "label" },
    { text = tostring(info.bufnr), style = "number" },
  })
  cb:spans({
    { text = "  Line: ", style = "label" },
    { text = tostring(info.line_num), style = "number" },
    { text = ", Column: " },
    { text = tostring(info.col), style = "number" },
  })
  if info.line_text then
    cb:spans({
      { text = "  Line text: ", style = "label" },
      { text = info.line_text:sub(1, 60), style = "muted" },
    })
  end
  cb:blank()
end

---Helper: Add a key-value pair
---@param cb ContentBuilder The content builder
---@param label string Label text
---@param value any Value to display
---@param value_style string? Style for value (default: "value")
function M.add_field(cb, label, value, value_style)
  value_style = value_style or "value"
  cb:spans({
    { text = "  " .. label .. ": ", style = "label" },
    { text = tostring(value), style = value_style },
  })
end

---Helper: Add a summary count
---@param cb ContentBuilder The content builder
---@param label string Label text
---@param count number Count value
function M.add_count(cb, label, count)
  cb:spans({
    { text = "  " .. label .. ": ", style = "label" },
    { text = tostring(count), style = "number" },
  })
end

---Helper: Create a simple viewer that just shows JSON data
---@param title string Window title
---@param data table Data to display as JSON
---@param header_text string? Optional header text
---@return ViewerInstance viewer
function M.show_json(title, data, header_text)
  local viewer = M.create({ title = title })

  viewer:show(function(cb)
    if header_text then
      M.add_header(cb, header_text)
    end

    local json_lines = JsonUtils.prettify_lines(data)
    for _, line in ipairs(json_lines) do
      cb:line(line)
    end
  end)

  return viewer
end

return M
