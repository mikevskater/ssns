---@class ContentBuilder
---Build styled content for floating windows using theme colors
---Maps semantic content types to existing SSNS theme highlight groups
---Supports input fields for interactive forms
---@module ssns.ui.core.content_builder
local ContentBuilder = {}
ContentBuilder.__index = ContentBuilder

---Semantic style mappings to SSNS theme highlight groups
---These map user-friendly style names to actual theme groups
local STYLE_MAPPINGS = {
  -- Headers and titles
  header = "SsnsUiTitle",           -- ui_title (purple bold)
  title = "SsnsUiTitle",            -- ui_title
  section = "SsnsKeywordStatement", -- keyword_statement (purple bold)
  
  -- Labels and values
  label = "SsnsType",               -- keyword_datatype (cyan) - for field names
  value = "SsnsColumn",             -- column (light blue) - for values
  key = "SsnsKey",                  -- key (blue) - for key names
  
  -- Emphasis styles
  emphasis = "SsnsFunction",        -- function (cyan)
  strong = "SsnsKeyword",           -- keyword (blue bold)
  highlight = "SsnsSearch",         -- search highlighting
  
  -- Status styles
  success = "SsnsStatusConnected",  -- status_connected (green/cyan)
  warning = "SsnsStatusConnecting", -- status_connecting (yellow)
  error = "SsnsStatusError",        -- status_error (red)
  
  -- Muted/subtle styles
  muted = "SsnsUiHint",             -- ui_hint (gray)
  dim = "SsnsSeparator",            -- separator/comment-like
  comment = "SsnsComment",          -- comment (green italic)
  
  -- Object types (for semantic content)
  server = "SsnsServer",
  database = "SsnsDatabase",
  schema = "SsnsSchema",
  table = "SsnsTable",
  view = "SsnsView",
  column = "SsnsColumn",
  procedure = "SsnsProcedure",
  func = "SsnsFunction",            -- 'function' is reserved
  index = "SsnsIndex",
  param = "SsnsParameter",
  
  -- Code/syntax styles
  keyword = "SsnsKeyword",
  string = "SsnsString",
  number = "SsnsNumber",
  operator = "SsnsOperator",
  
  -- Input field styles
  input = "SsnsFloatInput",         -- Input field background
  input_active = "SsnsFloatInputActive", -- Active/focused input
  input_placeholder = "SsnsUiHint", -- Placeholder text
  
  -- Special
  normal = nil,                     -- No highlight, use default
  none = nil,                       -- Explicit no highlight
}

---@class ContentLine
---@field text string The line text
---@field highlights ContentHighlight[] Array of highlights for this line

---@class ContentHighlight
---@field col_start number 0-indexed start column
---@field col_end number 0-indexed end column
---@field style string Style name from STYLE_MAPPINGS

---@class InputField
---@field key string Unique identifier for the input
---@field line number 1-indexed line number
---@field col_start number 0-indexed start column of input value area
---@field col_end number 0-indexed end column of input value area
---@field width number Total width of input field
---@field value string Current value
---@field default string Default/initial value
---@field placeholder string Placeholder text when empty
---@field label string? Optional label text before input

---@class ContentBuilderState
---@field lines ContentLine[] Built content lines
---@field namespace number|nil Highlight namespace
---@field inputs table<string, InputField> Map of input key -> field info

---Create a new ContentBuilder instance
---@return ContentBuilder
function ContentBuilder.new()
  local self = setmetatable({}, ContentBuilder)
  self._lines = {}  -- Array of { text = string, highlights = {} }
  self._namespace = nil
  self._inputs = {}  -- Map of key -> InputField
  self._input_order = {}  -- Ordered list of input keys for Tab navigation
  return self
end

---Get the highlight group for a style
---@param style string Style name
---@return string|nil group Highlight group name or nil for normal
function ContentBuilder.get_highlight(style)
  return STYLE_MAPPINGS[style]
end

---Add a plain text line (no special highlighting)
---@param text string Line text
---@return ContentBuilder self For chaining
function ContentBuilder:line(text)
  table.insert(self._lines, {
    text = text or "",
    highlights = {},
  })
  return self
end

---Add an empty line
---@return ContentBuilder self For chaining
function ContentBuilder:blank()
  return self:line("")
end

---Add a styled line (entire line has one style)
---@param text string Line text
---@param style string Style name from STYLE_MAPPINGS
---@return ContentBuilder self For chaining
function ContentBuilder:styled(text, style)
  local line = {
    text = text or "",
    highlights = {},
  }
  if style and STYLE_MAPPINGS[style] then
    table.insert(line.highlights, {
      col_start = 0,
      col_end = #text,
      style = style,
    })
  end
  table.insert(self._lines, line)
  return self
end

---Add a header line (styled as header)
---@param text string Header text
---@return ContentBuilder self For chaining
function ContentBuilder:header(text)
  return self:styled(text, "header")
end

---Add a section header (styled as section)
---@param text string Section text
---@return ContentBuilder self For chaining
function ContentBuilder:section(text)
  return self:styled(text, "section")
end

---Add a separator line
---@param char string? Character to repeat (default: "─")
---@param width number? Width (default: 50)
---@return ContentBuilder self For chaining
function ContentBuilder:separator(char, width)
  char = char or "─"
  width = width or 50
  return self:styled(string.rep(char, width), "muted")
end

---Add a label: value line
---@param label string Label text
---@param value any Value (will be tostring'd)
---@param opts table? Options: { label_style = "label", value_style = "value", separator = ": " }
---@return ContentBuilder self For chaining
function ContentBuilder:label_value(label, value, opts)
  opts = opts or {}
  local label_style = opts.label_style or "label"
  local value_style = opts.value_style or "value"
  local sep = opts.separator or ": "
  
  local value_str = tostring(value)
  local text = label .. sep .. value_str
  
  local line = {
    text = text,
    highlights = {},
  }
  
  -- Highlight label
  if STYLE_MAPPINGS[label_style] then
    table.insert(line.highlights, {
      col_start = 0,
      col_end = #label,
      style = label_style,
    })
  end
  
  -- Highlight value
  if STYLE_MAPPINGS[value_style] then
    table.insert(line.highlights, {
      col_start = #label + #sep,
      col_end = #text,
      style = value_style,
    })
  end
  
  table.insert(self._lines, line)
  return self
end

---Add a key: value line (like label_value but with key styling)
---@param key string Key text
---@param value any Value
---@return ContentBuilder self For chaining
function ContentBuilder:key_value(key, value)
  return self:label_value(key, value, { label_style = "key", value_style = "value" })
end

---Add a line with mixed styles using spans
---@param spans table[] Array of { text = string, style = string? }
---@return ContentBuilder self For chaining
function ContentBuilder:spans(spans)
  local text_parts = {}
  local highlights = {}
  local pos = 0
  
  for _, span in ipairs(spans) do
    local span_text = span.text or ""
    table.insert(text_parts, span_text)
    
    if span.style and STYLE_MAPPINGS[span.style] then
      table.insert(highlights, {
        col_start = pos,
        col_end = pos + #span_text,
        style = span.style,
      })
    end
    
    pos = pos + #span_text
  end
  
  table.insert(self._lines, {
    text = table.concat(text_parts, ""),
    highlights = highlights,
  })
  return self
end

---Add an input field
---@param key string Unique identifier for retrieving the value
---@param opts table Options: { label = string?, value = string?, placeholder = string?, width = number?, label_style = string? }
---@return ContentBuilder self For chaining
function ContentBuilder:input(key, opts)
  opts = opts or {}
  local label = opts.label or ""
  local value = opts.value or ""
  local placeholder = opts.placeholder or ""
  local width = opts.width or 20
  local label_style = opts.label_style or "label"
  local separator = opts.separator or ": "
  
  -- Build the line text
  local prefix = ""
  if label ~= "" then
    prefix = label .. separator
  end
  
  -- Display value or placeholder
  local display_text = value
  local is_placeholder = false
  if value == "" and placeholder ~= "" then
    display_text = placeholder
    is_placeholder = true
  end
  
  -- Pad or truncate display text to fit width
  if #display_text < width then
    display_text = display_text .. string.rep(" ", width - #display_text)
  elseif #display_text > width then
    display_text = display_text:sub(1, width)
  end
  
  -- Build full line: "Label: [value_______]"
  local input_start = #prefix
  local text = prefix .. "[" .. display_text .. "]"
  local input_value_start = input_start + 1  -- After "["
  local input_value_end = input_value_start + width  -- Before "]"
  
  local line = {
    text = text,
    highlights = {},
  }
  
  -- Highlight label
  if label ~= "" and STYLE_MAPPINGS[label_style] then
    table.insert(line.highlights, {
      col_start = 0,
      col_end = #label,
      style = label_style,
    })
  end
  
  -- Highlight brackets
  table.insert(line.highlights, {
    col_start = input_start,
    col_end = input_start + 1,
    style = "muted",
  })
  table.insert(line.highlights, {
    col_start = input_value_end,
    col_end = input_value_end + 1,
    style = "muted",
  })
  
  -- Highlight input value area
  local value_style = is_placeholder and "input_placeholder" or "input"
  table.insert(line.highlights, {
    col_start = input_value_start,
    col_end = input_value_end,
    style = value_style,
  })
  
  table.insert(self._lines, line)
  
  -- Store input field info
  local line_num = #self._lines
  self._inputs[key] = {
    key = key,
    line = line_num,
    col_start = input_value_start,
    col_end = input_value_end,
    width = width,
    value = value,
    default = value,
    placeholder = placeholder,
    label = label,
  }
  table.insert(self._input_order, key)
  
  return self
end

---Add an input field with label on same line
---Supports two call patterns:
---  labeled_input(key, label, opts) -- original pattern
---  labeled_input(label, key, value, width) -- convenience pattern
---@param arg1 string First argument (key or label)
---@param arg2 string Second argument (label or key)
---@param arg3 table|string|nil Third argument (opts table, value string, or nil)
---@param arg4 number? Fourth argument (width, only for convenience pattern)
---@return ContentBuilder self For chaining
function ContentBuilder:labeled_input(arg1, arg2, arg3, arg4)
  local key, label, opts
  
  -- Detect which call pattern is being used
  if type(arg3) == "table" then
    -- Original pattern: labeled_input(key, label, opts)
    key = arg1
    label = arg2
    opts = arg3
  else
    -- Convenience pattern: labeled_input(label, key, value, width)
    label = arg1
    key = arg2
    opts = {
      value = arg3 or "",
      width = arg4,
    }
  end
  
  opts = opts or {}
  opts.label = label
  return self:input(key, opts)
end

---Get all input field definitions
---@return table<string, InputField> inputs Map of key -> InputField
function ContentBuilder:get_inputs()
  return self._inputs
end

---Get ordered list of input keys (for Tab navigation)
---@return string[] keys Ordered input keys
function ContentBuilder:get_input_order()
  return self._input_order
end

---Get a specific input field
---@param key string Input key
---@return InputField? field Input field or nil
function ContentBuilder:get_input(key)
  return self._inputs[key]
end

---Update an input field's value (for re-rendering)
---@param key string Input key
---@param value string New value
---@return ContentBuilder self For chaining
function ContentBuilder:set_input_value(key, value)
  local input = self._inputs[key]
  if input then
    input.value = value
  end
  return self
end

---Add a status line with icon
---@param status "success"|"warning"|"error"|"muted" Status type
---@param text string Status text
---@return ContentBuilder self For chaining
function ContentBuilder:status(status, text)
  local icons = {
    success = "✓",
    warning = "⚠",
    error = "✗",
    muted = "•",
  }
  local icon = icons[status] or "•"
  return self:spans({
    { text = icon .. " ", style = status },
    { text = text, style = status },
  })
end

---Add a list item with optional style
---@param text string Item text
---@param style string? Style for the text
---@param prefix string? Prefix (default: "  • ")
---@return ContentBuilder self For chaining
function ContentBuilder:list_item(text, style, prefix)
  prefix = prefix or "  • "
  if style then
    return self:spans({
      { text = prefix, style = "muted" },
      { text = text, style = style },
    })
  else
    return self:line(prefix .. text)
  end
end

---Add a table row with columns
---@param columns table[] Array of { text = string, width = number?, style = string? }
---@return ContentBuilder self For chaining
function ContentBuilder:table_row(columns)
  local spans = {}
  for i, col in ipairs(columns) do
    local text = col.text or ""
    local width = col.width
    
    -- Pad or truncate to width
    if width then
      if #text < width then
        text = text .. string.rep(" ", width - #text)
      elseif #text > width then
        text = text:sub(1, width - 1) .. "…"
      end
    end
    
    -- Add separator between columns
    if i > 1 then
      table.insert(spans, { text = " ", style = nil })
    end
    
    table.insert(spans, { text = text, style = col.style })
  end
  
  return self:spans(spans)
end

---Add indented content
---@param text string Text to indent
---@param level number? Indent level (default: 1)
---@param style string? Style for the text
---@return ContentBuilder self For chaining
function ContentBuilder:indent(text, level, style)
  level = level or 1
  local prefix = string.rep("  ", level)
  if style then
    return self:spans({
      { text = prefix },
      { text = text, style = style },
    })
  else
    return self:line(prefix .. text)
  end
end

---Build and return the plain text lines (for buffer content)
---@return string[] lines Array of text lines
function ContentBuilder:build_lines()
  local lines = {}
  for _, line in ipairs(self._lines) do
    table.insert(lines, line.text)
  end
  return lines
end

---Build and return highlight data
---@return table[] highlights Array of { line = number, col_start = number, col_end = number, hl_group = string }
function ContentBuilder:build_highlights()
  local highlights = {}
  for line_idx, line in ipairs(self._lines) do
    for _, hl in ipairs(line.highlights) do
      local hl_group = STYLE_MAPPINGS[hl.style]
      if hl_group then
        table.insert(highlights, {
          line = line_idx - 1,  -- 0-indexed
          col_start = hl.col_start,
          col_end = hl.col_end,
          hl_group = hl_group,
        })
      end
    end
  end
  return highlights
end

---Apply highlights to a buffer
---@param bufnr number Buffer number
---@param ns_id number? Namespace ID (creates one if nil)
---@return number ns_id The namespace ID used
function ContentBuilder:apply_to_buffer(bufnr, ns_id)
  ns_id = ns_id or vim.api.nvim_create_namespace("ssns_content_builder")
  
  -- Clear existing highlights in namespace
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  -- Apply new highlights
  local highlights = self:build_highlights()
  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end
  
  return ns_id
end

---Build everything and apply to a buffer in one call
---@param bufnr number Buffer number
---@param ns_id number? Namespace ID
---@return string[] lines The lines that were set
---@return number ns_id The namespace ID used
function ContentBuilder:render_to_buffer(bufnr, ns_id)
  local lines = self:build_lines()
  
  -- Set buffer content
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  
  -- Apply highlights
  ns_id = self:apply_to_buffer(bufnr, ns_id)
  
  return lines, ns_id
end

---Get available style names
---@return string[] styles Array of available style names
function ContentBuilder.get_styles()
  local styles = {}
  for name, _ in pairs(STYLE_MAPPINGS) do
    table.insert(styles, name)
  end
  table.sort(styles)
  return styles
end

---Debug: print all styles and their mappings
function ContentBuilder.print_styles()
  print("ContentBuilder Style Mappings:")
  print(string.rep("-", 40))
  local styles = ContentBuilder.get_styles()
  for _, name in ipairs(styles) do
    local group = STYLE_MAPPINGS[name] or "(none)"
    print(string.format("  %-15s -> %s", name, group))
  end
end

return ContentBuilder
