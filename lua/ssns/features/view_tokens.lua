---@class ViewTokens
---View tokenizer output in a floating window
---Displays the tokenized representation of the current buffer for debugging
---@module ssns.features.view_tokens
local ViewTokens = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local Tokenizer = require('ssns.completion.tokenizer')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewTokens.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View tokens for the current buffer
---Tokenizes the buffer content and displays tokens in a floating window
function ViewTokens.view_tokens()
  -- Close any existing float
  ViewTokens.close_current_float()

  -- Get current buffer content
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text == "" then
    vim.notify("SSNS: Buffer is empty", vim.log.levels.WARN)
    return
  end

  -- Tokenize the SQL
  local tokens = Tokenizer.tokenize(text)

  if not tokens or #tokens == 0 then
    vim.notify("SSNS: No tokens generated", vim.log.levels.WARN)
    return
  end

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Tokenizer Output")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Summary section
  table.insert(display_lines, "Summary")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Total tokens: %d", #tokens))

  -- Count by type
  local type_counts = {}
  for _, token in ipairs(tokens) do
    type_counts[token.type] = (type_counts[token.type] or 0) + 1
  end

  -- Sort types for consistent output
  local sorted_types = {}
  for t in pairs(type_counts) do
    table.insert(sorted_types, t)
  end
  table.sort(sorted_types)

  table.insert(display_lines, "")
  table.insert(display_lines, "  By type:")
  for _, t in ipairs(sorted_types) do
    table.insert(display_lines, string.format("    %s: %d", t, type_counts[t]))
  end
  table.insert(display_lines, "")

  -- Token table section
  table.insert(display_lines, "Token List")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, "")

  -- Header
  table.insert(display_lines, string.format("  %-4s  %-15s  %-5s  %-4s  %s",
    "#", "Type", "Line", "Col", "Text"))
  table.insert(display_lines, "  " .. string.rep("-", 60))

  -- Token rows (limit to first 500 for performance)
  local max_display = math.min(#tokens, 500)
  for i = 1, max_display do
    local token = tokens[i]
    local text_display = token.text
    -- Truncate long text
    if #text_display > 30 then
      text_display = text_display:sub(1, 27) .. "..."
    end
    -- Escape newlines for display
    text_display = text_display:gsub("\n", "\\n"):gsub("\r", "\\r")

    local category_suffix = ""
    if token.keyword_category then
      category_suffix = string.format(" [%s]", token.keyword_category)
    end

    table.insert(display_lines, string.format("  %-4d  %-15s  %-5d  %-4d  %s%s",
      i, token.type, token.line, token.col, text_display, category_suffix))
  end

  if #tokens > max_display then
    table.insert(display_lines, "")
    table.insert(display_lines, string.format("  ... and %d more tokens (truncated)", #tokens - max_display))
  end

  -- Add JSON section for full token list
  table.insert(display_lines, "")
  table.insert(display_lines, "")
  table.insert(display_lines, "Full JSON Output")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Prettify the tokens (limit for JSON output too)
  local json_tokens = tokens
  if #tokens > 100 then
    json_tokens = {}
    for i = 1, 100 do
      json_tokens[i] = tokens[i]
    end
    table.insert(display_lines, string.format("(Showing first 100 of %d tokens)", #tokens))
    table.insert(display_lines, "")
  end

  local json_lines = JsonUtils.prettify_lines(json_tokens)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Tokens",
    border = "rounded",
    filetype = "json",
    min_width = 70,
    max_width = 120,
    max_height = 40,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh: retokenize and update content
        ViewTokens.view_tokens()
      end,
    },
    footer = "q/Esc: close | r: refresh",
  })
end

return ViewTokens
