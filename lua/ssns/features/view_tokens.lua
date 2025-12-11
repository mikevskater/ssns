---@class ViewTokens
---View tokenizer output in a floating window
---Displays the tokenized representation of the current buffer for debugging
---@module ssns.features.view_tokens
local ViewTokens = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local JsonUtils = require('ssns.utils.json')
local Tokenizer = require('ssns.completion.tokenizer')
local StatementCache = require('ssns.completion.statement_cache')

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

  -- Use cached tokens from StatementCache (avoids redundant tokenization)
  local cache = StatementCache.get_or_build_cache(bufnr)
  local tokens = cache and cache.tokens
  if not tokens or #tokens == 0 then
    -- Fallback to direct tokenization if cache unavailable
    tokens = Tokenizer.tokenize(text)
  end

  if not tokens or #tokens == 0 then
    vim.notify("SSNS: No tokens generated", vim.log.levels.WARN)
    return
  end

  -- Build styled content
  local cb = ContentBuilder.new()

  cb:header("Tokenizer Output")
  cb:separator("=", 50)
  cb:blank()

  -- Summary section
  cb:section("Summary")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Total tokens: ", style = "label" },
    { text = tostring(#tokens), style = "number" },
  })

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

  cb:blank()
  cb:styled("  By type:", "label")
  for _, t in ipairs(sorted_types) do
    cb:spans({
      { text = "    " },
      { text = t, style = "keyword" },
      { text = ": " },
      { text = tostring(type_counts[t]), style = "number" },
    })
  end
  cb:blank()

  -- Token table section
  cb:section("Token List")
  cb:separator("-", 30)
  cb:blank()

  -- Header
  cb:spans({
    { text = "  " },
    { text = string.format("%-4s  %-15s  %-5s  %-4s  %s", "#", "Type", "Line", "Col", "Text"), style = "label" },
  })
  cb:line("  " .. string.rep("-", 60))

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

    local type_style = "muted"
    if token.type == "KEYWORD" then
      type_style = "keyword"
    elseif token.type == "IDENTIFIER" then
      type_style = "value"
    elseif token.type == "STRING" then
      type_style = "string"
    elseif token.type == "NUMBER" then
      type_style = "number"
    elseif token.type == "OPERATOR" then
      type_style = "emphasis"
    elseif token.type == "COMMENT" then
      type_style = "muted"
    end

    local category_suffix = ""
    if token.keyword_category then
      category_suffix = string.format(" [%s]", token.keyword_category)
    end

    cb:spans({
      { text = "  " },
      { text = string.format("%-4d  ", i), style = "muted" },
      { text = string.format("%-15s  ", token.type), style = type_style },
      { text = string.format("%-5d  ", token.line), style = "number" },
      { text = string.format("%-4d  ", token.col), style = "number" },
      { text = text_display, style = "value" },
      { text = category_suffix, style = "muted" },
    })
  end

  if #tokens > max_display then
    cb:blank()
    cb:spans({
      { text = "  ... and " },
      { text = tostring(#tokens - max_display), style = "number" },
      { text = " more tokens (truncated)", style = "muted" },
    })
  end

  -- Add JSON section for full token list
  cb:blank()
  cb:blank()
  cb:header("Full JSON Output")
  cb:separator("=", 50)
  cb:blank()

  -- Prettify the tokens (limit for JSON output too)
  local json_tokens = tokens
  if #tokens > 100 then
    json_tokens = {}
    for i = 1, 100 do
      json_tokens[i] = tokens[i]
    end
    cb:spans({
      { text = "(Showing first 100 of " },
      { text = tostring(#tokens), style = "number" },
      { text = " tokens)", style = "muted" },
    })
    cb:blank()
  end

  local json_lines = JsonUtils.prettify_lines(json_tokens)
  for _, line in ipairs(json_lines) do
    cb:line(line)
  end

  -- Create floating window
  current_float = UiFloat.create_styled(cb, {
    title = "Tokens",
    border = "rounded",
    min_width = 70,
    max_width = 120,
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

