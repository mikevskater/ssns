---@class FormatterOutput
---Thin output layer that reads pass annotations and builds formatted SQL.
---
---This module expects tokens to be fully annotated by the pass pipeline:
---  - token.text (cased by 06_casing)
---  - token.space_before (from 05_spacing)
---  - token.newline_before (from 04_structure)
---  - token.indent_level (from 04_structure)
---  - token.empty_line_before (from 04_structure)
---  - token.trailing_newline (from 04_structure)
---  - token.remove (from 07_transform) - skip this token
---  - token.insert_before (from 07_transform) - tokens to add before
---  - token.insert_after (from 07_transform) - tokens to add after
local Output = {}

-- =============================================================================
-- Helpers
-- =============================================================================

---Get indentation string for a given level
---@param config table Formatter configuration
---@param level number Indentation level
---@return string
local function get_indent(config, level)
  if level <= 0 then
    return ""
  end
  local indent_char = config.use_tabs and "\t" or " "
  local indent_size = config.indent_size or 4
  return string.rep(indent_char, level * indent_size)
end

---Trim trailing whitespace from a string
---@param s string
---@return string
local function rtrim(s)
  return s:gsub("%s+$", "")
end

-- =============================================================================
-- Main Output Generation
-- =============================================================================

---Generate formatted SQL from annotated tokens
---@param tokens table[] Array of annotated tokens
---@param config table Formatter configuration
---@return string Formatted SQL
function Output.generate(tokens, config)
  config = config or {}

  local result = {}         -- Array of output lines
  local current_line = {}   -- Current line being built
  local line_has_content = false

  ---Flush current line to result
  local function flush_line()
    if #current_line > 0 then
      local line_text = table.concat(current_line, "")
      line_text = rtrim(line_text)  -- Remove trailing whitespace
      table.insert(result, line_text)
      current_line = {}
      line_has_content = false
    end
  end

  ---Add indentation to current line
  ---@param level number Indent level
  local function add_indent(level)
    local indent = get_indent(config, level)
    if indent ~= "" then
      table.insert(current_line, indent)
    end
  end

  ---Output a single token (handles newlines, spacing, and text)
  ---@param tok table Token to output
  ---@param is_inserted boolean True if this is an inserted token
  local function output_token(tok, is_inserted)
    -- Handle newline before token (only for inserted tokens - main tokens handle this outside)
    if is_inserted and tok.newline_before then
      flush_line()
      add_indent(tok.indent_level or 0)
      line_has_content = false
    end
    -- Handle spacing before token
    if line_has_content and tok.space_before then
      table.insert(current_line, " ")
    end
    -- Handle alignment padding (from 08_align pass)
    if tok.align_padding and tok.align_padding > 0 then
      table.insert(current_line, string.rep(" ", tok.align_padding))
    end
    -- Add the token text
    table.insert(current_line, tok.text)
    line_has_content = true
  end

  -- Process each token
  for i, token in ipairs(tokens) do
    -- Skip whitespace/newline tokens from input (we control formatting)
    if token.type == "whitespace" or token.type == "newline" then
      goto continue
    end

    -- Skip tokens marked for removal by transform pass
    if token.remove then
      goto continue
    end

    -- Handle empty line before (e.g., before JOIN with empty_line_before_join)
    if token.empty_line_before then
      flush_line()
      table.insert(result, "")  -- Add empty line
    end

    -- Handle newline before token
    if token.newline_before then
      flush_line()
      add_indent(token.indent_level or 0)
      line_has_content = false
    end

    -- Output tokens inserted before this token (from transform pass)
    if token.insert_before then
      for _, inserted in ipairs(token.insert_before) do
        output_token(inserted, true)  -- is_inserted = true
      end
    end

    -- Output the main token
    output_token(token, false)  -- is_inserted = false

    -- Output tokens inserted after this token (from transform pass)
    if token.insert_after then
      for _, inserted in ipairs(token.insert_after) do
        output_token(inserted, true)  -- is_inserted = true
      end
    end

    -- Handle trailing newline (e.g., after comma in stacked style)
    if token.trailing_newline then
      flush_line()
      -- Next token will add its own indent
    end

    -- Handle semicolon - end of statement
    if token.type == "semicolon" then
      flush_line()
      -- Add blank lines between statements
      -- blank_line_between_statements is how many to add (default 1)
      -- max_consecutive_blank_lines is the limit (default 2)
      local blank_count = config.blank_line_between_statements or 1
      local max_blank = config.max_consecutive_blank_lines
      if max_blank ~= nil then
        blank_count = math.min(blank_count, max_blank)
      end
      for _ = 1, blank_count do
        table.insert(result, "")
      end
    end

    -- Handle GO - batch separator
    if token.type == "go" then
      -- GO should be on its own line
      flush_line()
      -- Add blank lines after GO
      local blank_lines = config.blank_line_after_go or 1
      for _ = 1, blank_lines do
        table.insert(result, "")
      end
    end

    ::continue::
  end

  -- Flush any remaining content
  flush_line()

  -- Remove trailing empty lines
  while #result > 0 and result[#result] == "" do
    table.remove(result)
  end

  -- Join lines and return
  return table.concat(result, "\n")
end

return Output
