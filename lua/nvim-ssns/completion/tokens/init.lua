---Token utilities module
---Re-exports navigation functions and provides identifier utilities
---@module ssns.completion.tokens
local Tokens = {}

local Navigation = require('nvim-ssns.completion.tokens.navigation')
local Tokenizer = require('nvim-ssns.completion.tokenizer')

-- Re-export navigation functions
Tokens.get_token_at_position = Navigation.get_token_at_position
Tokens.get_tokens_before_cursor = Navigation.get_tokens_before_cursor
Tokens.get_token_after_cursor = Navigation.get_token_after_cursor
Tokens.find_previous_token_of_type = Navigation.find_previous_token_of_type
Tokens.find_previous_keyword = Navigation.find_previous_keyword
Tokens.is_in_string_or_comment = Navigation.is_in_string_or_comment
Tokens.extract_prefix = Navigation.extract_prefix

-- ============================================================================
-- Tokenization
-- ============================================================================

---Tokenize buffer text and return tokens
---@param text string SQL text
---@return Token[] tokens
function Tokens.tokenize(text)
  return Tokenizer.tokenize(text)
end

---Get tokens from a buffer (uses cache when available)
---@param bufnr number Buffer number
---@return Token[] tokens
function Tokens.get_buffer_tokens(bufnr)
  -- Try cached tokens first (avoids re-tokenization)
  local StatementCache = require('nvim-ssns.completion.statement_cache')
  local cached = StatementCache.get_tokens(bufnr)
  if cached then
    return cached
  end

  -- Fallback: tokenize directly (for non-SQL buffers or edge cases)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  return Tokenizer.tokenize(text)
end

-- ============================================================================
-- Identifier Utility Functions
-- Simple string operations that replace regex patterns across the codebase
-- ============================================================================

---Check if an identifier is a temp table (starts with #)
---Replaces regex pattern: identifier:match("^#")
---@param identifier string Identifier to check
---@return boolean is_temp True if identifier starts with #
function Tokens.is_temp_table(identifier)
  if not identifier or type(identifier) ~= "string" or #identifier == 0 then
    return false
  end
  return identifier:sub(1, 1) == "#"
end

---Check if an identifier is a global temp table (starts with ##)
---Replaces regex pattern: identifier:match("^##")
---@param identifier string Identifier to check
---@return boolean is_global_temp True if identifier starts with ##
function Tokens.is_global_temp_table(identifier)
  if not identifier or type(identifier) ~= "string" or #identifier < 2 then
    return false
  end
  return identifier:sub(1, 2) == "##"
end

---Strip surrounding brackets, quotes, or backticks from an identifier
---Replaces regex patterns like: gsub("^%[(.-)%]$", "%1")
---@param identifier string Identifier with possible brackets/quotes
---@return string clean Cleaned identifier without surrounding delimiters
function Tokens.strip_identifier_quotes(identifier)
  if not identifier or type(identifier) ~= "string" or #identifier < 2 then
    return identifier or ""
  end

  local first = identifier:sub(1, 1)
  local last = identifier:sub(-1)

  -- Check for matching delimiters
  if first == "[" and last == "]" then
    return identifier:sub(2, -2)
  elseif first == '"' and last == '"' then
    return identifier:sub(2, -2)
  elseif first == "`" and last == "`" then
    return identifier:sub(2, -2)
  end

  return identifier
end

---Extract the last part of a dot-separated qualified name
---Replaces regex pattern: table_name:match("%.([^%.]+)$")
---@param qualified_name string Qualified name like "schema.table" or "db.schema.table"
---@return string last_part The last part after the final dot, or the whole string if no dots
function Tokens.get_last_name_part(qualified_name)
  if not qualified_name or type(qualified_name) ~= "string" then
    return ""
  end

  -- Find the last dot
  local last_dot = qualified_name:match(".*()%.")
  if last_dot then
    return qualified_name:sub(last_dot + 1)
  end

  return qualified_name
end

---Check if a string starts with a given prefix
---Replaces regex pattern: str:match("^prefix")
---@param str string String to check
---@param prefix string Prefix to look for
---@return boolean starts_with True if str starts with prefix
function Tokens.starts_with(str, prefix)
  if not str or not prefix then
    return false
  end
  return str:sub(1, #prefix) == prefix
end

---Extract bracketed identifier from end of text
---Handles pattern: [identifier] at end of string (with optional trailing whitespace)
---Replaces regex pattern: text:match("%[([^%]]+)%]%s*$")
---@param text string Text to extract from
---@return string? identifier The identifier inside brackets, or nil
function Tokens.extract_trailing_bracketed(text)
  if not text or type(text) ~= "string" then
    return nil
  end

  -- Trim trailing whitespace
  local trimmed = text:gsub("%s+$", "")
  if #trimmed < 3 then
    return nil
  end

  -- Check if ends with ]
  if trimmed:sub(-1) ~= "]" then
    return nil
  end

  -- Find matching [
  local bracket_start = trimmed:reverse():find("%[", 1, true)
  if not bracket_start then
    return nil
  end

  -- Extract the content between brackets
  local start_idx = #trimmed - bracket_start + 1
  if start_idx < 1 then
    return nil
  end

  return trimmed:sub(start_idx + 1, -2)  -- Remove [ and ]
end

---Extract identifier (word characters with dots) from end of text
---Handles pattern: word.word.word at end of string (with optional trailing whitespace)
---Replaces regex pattern: text:match("([%w_%.]+)%s*$")
---@param text string Text to extract from
---@return string? identifier The identifier/qualified name, or nil
function Tokens.extract_trailing_identifier(text)
  if not text or type(text) ~= "string" then
    return nil
  end

  -- Trim trailing whitespace
  local trimmed = text:gsub("%s+$", "")
  if #trimmed == 0 then
    return nil
  end

  -- Walk backward from end collecting valid identifier chars
  local result = {}
  for i = #trimmed, 1, -1 do
    local char = trimmed:sub(i, i)
    -- Valid identifier chars: alphanumeric, underscore, dot
    if char:match("[%w_%.]") then
      table.insert(result, 1, char)
    else
      break
    end
  end

  if #result == 0 then
    return nil
  end

  return table.concat(result)
end

return Tokens
