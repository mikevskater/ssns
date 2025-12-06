---@class TokenContext
---Token-based context detection utilities for IntelliSense
---Replaces regex-based parsing with accurate token stream analysis
---@module ssns.completion.token_context
local TokenContext = {}

local Tokenizer = require('ssns.completion.tokenizer')

---@class QualifiedName
---@field database string? Database name (for db.schema.table)
---@field schema string? Schema name (for schema.table or db.schema.table)
---@field table string? Table/view/object name
---@field column string? Column name (for table.column)
---@field alias string? Could be alias or identifier
---@field parts string[] All parts in order (first to last)
---@field has_trailing_dot boolean Whether there's a dot at the end (schema. triggers completion)

---Get the token at or immediately before a cursor position
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return Token? token Token at or before cursor
---@return number? index Index of the token in the array
function TokenContext.get_token_at_position(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil
  end

  local best_token = nil
  local best_index = nil

  for i, token in ipairs(tokens) do
    -- Token covers position if:
    -- 1. Token starts on a previous line, OR
    -- 2. Token is on the same line and starts before or at the column
    local token_end_col = token.col + #token.text - 1

    if token.line < line then
      -- Token is on a previous line - could be multi-line (string/comment)
      -- For now, skip - we want tokens on or just before cursor line
      best_token = token
      best_index = i
    elseif token.line == line then
      -- Token is on cursor line
      if token.col <= col then
        -- Token starts at or before cursor
        if token_end_col >= col then
          -- Cursor is within token
          return token, i
        else
          -- Token is before cursor, remember it as candidate
          best_token = token
          best_index = i
        end
      else
        -- Token starts after cursor, we've gone past
        break
      end
    elseif token.line > line then
      -- Past cursor line
      break
    end
  end

  return best_token, best_index
end

---Get N tokens before a cursor position (excluding comments)
---Returns tokens in reverse order (most recent first)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@param count number Number of tokens to return
---@return Token[] tokens Array of tokens (most recent first)
function TokenContext.get_tokens_before_cursor(tokens, line, col, count)
  if not tokens or #tokens == 0 then
    return {}
  end

  -- Find the token at/before cursor to get our starting point
  local _, start_index = TokenContext.get_token_at_position(tokens, line, col)
  if not start_index then
    return {}
  end

  local result = {}
  local i = start_index

  while i >= 1 and #result < count do
    local token = tokens[i]
    -- Skip comments
    if token.type ~= "comment" and token.type ~= "line_comment" then
      table.insert(result, token)
    end
    i = i - 1
  end

  return result
end

---Get the token immediately after cursor position
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return Token? token Token after cursor
function TokenContext.get_token_after_cursor(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil
  end

  for _, token in ipairs(tokens) do
    if token.line > line then
      return token
    elseif token.line == line and token.col > col then
      return token
    end
  end

  return nil
end

---Find the previous token of a specific type
---@param tokens Token[] Parsed tokens
---@param start_index number Index to start searching backward from
---@param token_type string|string[] Token type(s) to find
---@return Token? token Found token
---@return number? index Index of found token
function TokenContext.find_previous_token_of_type(tokens, start_index, token_type)
  if not tokens or start_index < 1 then
    return nil, nil
  end

  local types = type(token_type) == "table" and token_type or { token_type }
  local type_set = {}
  for _, t in ipairs(types) do
    type_set[t] = true
  end

  for i = start_index, 1, -1 do
    local token = tokens[i]
    if type_set[token.type] then
      return token, i
    end
  end

  return nil, nil
end

---Find the previous keyword matching any in a list (case-insensitive)
---@param tokens Token[] Parsed tokens
---@param start_index number Index to start searching backward from
---@param keywords string[] Keywords to match (uppercase)
---@return Token? token Found keyword token
---@return number? index Index of found token
function TokenContext.find_previous_keyword(tokens, start_index, keywords)
  if not tokens or start_index < 1 then
    return nil, nil
  end

  local keyword_set = {}
  for _, kw in ipairs(keywords) do
    keyword_set[kw:upper()] = true
  end

  for i = start_index, 1, -1 do
    local token = tokens[i]
    if token.type == "keyword" and keyword_set[token.text:upper()] then
      return token, i
    end
  end

  return nil, nil
end

---Parse a qualified name from tokens before cursor
---Handles patterns like: dbo.Table, [schema].[table], db.schema.table, alias.column
---@param tokens Token[] Tokens before cursor (most recent first from get_tokens_before_cursor)
---@return QualifiedName qualified Parsed qualified name info
function TokenContext.parse_qualified_name_from_tokens(tokens)
  local result = {
    parts = {},
    has_trailing_dot = false,
  }

  if not tokens or #tokens == 0 then
    return result
  end

  -- Tokens are in reverse order (most recent first)
  -- Walk through looking for pattern: [identifier] [dot identifier]*

  local i = 1
  local parts = {}
  local saw_initial_dot = false

  -- Check if the first token is a dot (user just typed "schema.")
  if tokens[i] and tokens[i].type == "dot" then
    saw_initial_dot = true
    result.has_trailing_dot = true
    i = i + 1
  end

  -- Collect identifier/dot pairs walking backward
  while i <= #tokens do
    local token = tokens[i]

    if token.type == "identifier" or token.type == "bracket_id" then
      -- Found an identifier, add it
      local name = token.text
      -- Strip brackets from bracket_id
      if token.type == "bracket_id" then
        name = name:sub(2, -2)  -- Remove [ and ]
      end
      table.insert(parts, 1, name)  -- Insert at beginning since we're going backward
      i = i + 1

      -- Check for preceding dot
      if i <= #tokens and tokens[i].type == "dot" then
        i = i + 1
        -- Continue to next identifier
      else
        -- No more dots, we're done
        break
      end
    else
      -- Not an identifier, stop
      break
    end
  end

  -- Now parts is in forward order: {database, schema, table} or {schema, table} or {alias}
  result.parts = parts

  -- Determine what each part represents based on count and context
  local count = #parts
  if count == 0 then
    -- No parts, just a trailing dot
    return result
  elseif count == 1 then
    -- Single identifier - could be alias or partial name
    -- If there was a trailing dot, this is a qualifier (schema or alias)
    if saw_initial_dot then
      -- "dbo." -> schema = dbo (or could be alias, caller determines)
      result.schema = parts[1]
      result.alias = parts[1]  -- Could be either, context determines
    else
      -- "dbo" -> just an identifier being typed
      result.alias = parts[1]
    end
  elseif count == 2 then
    -- Two parts: schema.table or alias.column
    if saw_initial_dot then
      -- "db.schema." -> database = db, schema = schema
      result.database = parts[1]
      result.schema = parts[2]
    else
      -- "schema.table" or "alias.column"
      result.schema = parts[1]
      result.table = parts[2]
      result.alias = parts[1]  -- Could also be alias.column
      result.column = parts[2]
    end
  elseif count == 3 then
    -- Three parts: db.schema.table
    if saw_initial_dot then
      -- Unlikely but handle it
      result.database = parts[1]
      result.schema = parts[2]
      result.table = parts[3]
    else
      result.database = parts[1]
      result.schema = parts[2]
      result.table = parts[3]
    end
  elseif count >= 4 then
    -- Four or more: db.schema.table.column
    result.database = parts[1]
    result.schema = parts[2]
    result.table = parts[3]
    result.column = parts[4]
  end

  return result
end

---Determine if cursor is after a dot (trigger completion)
---@param tokens Token[] All tokens
---@param line number Cursor line
---@param col number Cursor column
---@return boolean is_after_dot
---@return QualifiedName? qualified Parsed qualified name if after dot
function TokenContext.is_dot_triggered(tokens, line, col)
  -- Get tokens before cursor
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 5)
  if #prev_tokens == 0 then
    return false, nil
  end

  -- Check if most recent non-whitespace token is a dot
  local first_token = prev_tokens[1]
  if first_token.type == "dot" then
    local qualified = TokenContext.parse_qualified_name_from_tokens(prev_tokens)
    return true, qualified
  end

  return false, nil
end

---Extract prefix (partial word being typed) from cursor position
---@param token Token? Token at cursor (may be partial)
---@param line number Cursor line
---@param col number Cursor column (1-indexed, cursor is BEFORE this column)
---@return string prefix Partial text being typed
function TokenContext.extract_prefix(token, line, col)
  if not token then
    return ""
  end

  -- If cursor is in the middle of a token, extract the part before cursor
  if token.line == line then
    local chars_into_token = col - token.col
    if chars_into_token > 0 and chars_into_token <= #token.text then
      return token.text:sub(1, chars_into_token)
    elseif chars_into_token <= 0 then
      return ""
    else
      return token.text
    end
  end

  -- Token is on a different line, return full text
  return token.text
end

---Tokenize buffer text and return tokens
---@param text string SQL text
---@return Token[] tokens
function TokenContext.tokenize(text)
  return Tokenizer.tokenize(text)
end

---Get tokens from a buffer
---@param bufnr number Buffer number
---@return Token[] tokens
function TokenContext.get_buffer_tokens(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  return Tokenizer.tokenize(text)
end

---Check if position is inside a string or comment
---@param tokens Token[] Tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean in_string_or_comment
function TokenContext.is_in_string_or_comment(tokens, line, col)
  local token, _ = TokenContext.get_token_at_position(tokens, line, col)
  if not token then
    return false
  end

  return token.type == "string"
      or token.type == "comment"
      or token.type == "line_comment"
end

---Extract prefix and trigger character using token analysis
---Replaces regex-based Context._extract_prefix_and_trigger()
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string prefix The partial word being typed
---@return string? trigger Trigger character (".", "[", " ", or nil)
function TokenContext.extract_prefix_and_trigger(tokens, line, col)
  local token_at, _ = TokenContext.get_token_at_position(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 3)

  local trigger = nil

  -- Check the most recent token for trigger characters
  if #prev_tokens > 0 then
    local first_token = prev_tokens[1]
    if first_token.type == "dot" then
      trigger = "."
    elseif first_token.type == "lparen" then
      -- Opening paren could be a trigger
      trigger = "("
    elseif first_token.text == "[" then
      -- Start of bracket identifier
      trigger = "["
    end

    -- Check for space trigger (keyword followed by space)
    -- This is trickier - we need to check if cursor is right after a space
    if not trigger and token_at then
      -- If we're at the start of a new token and previous was keyword
      if first_token.type == "keyword" then
        -- Check if there's whitespace between keyword and cursor
        local keyword_end_col = first_token.col + #first_token.text
        if first_token.line == line and keyword_end_col < col then
          trigger = " "
        end
      end
    end
  end

  -- Extract prefix from current token
  local prefix = ""
  if token_at then
    -- If cursor is within an identifier, extract the partial text
    if token_at.type == "identifier" or token_at.type == "keyword" or token_at.type == "bracket_id" then
      prefix = TokenContext.extract_prefix(token_at, line, col)
    end
  end

  return prefix, trigger
end

---Debug: Print tokens around cursor
---@param tokens Token[] Tokens
---@param line number Cursor line
---@param col number Cursor column
function TokenContext.debug_print_context(tokens, line, col)
  local token_at, idx = TokenContext.get_token_at_position(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 5)

  print(string.format("=== Token Context at line %d, col %d ===", line, col))

  if token_at then
    print(string.format("Token at cursor: [%d] type=%s text='%s' pos=%d:%d",
      idx or 0, token_at.type, token_at.text, token_at.line, token_at.col))
  else
    print("Token at cursor: nil")
  end

  print("Previous tokens (most recent first):")
  for i, t in ipairs(prev_tokens) do
    print(string.format("  [%d] type=%s text='%s' pos=%d:%d",
      i, t.type, t.text, t.line, t.col))
  end

  local is_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)
  print(string.format("Is dot triggered: %s", tostring(is_dot)))
  if qualified then
    print(string.format("Qualified name: parts=%s, has_trailing_dot=%s",
      table.concat(qualified.parts, "."),
      tostring(qualified.has_trailing_dot)))
    print(string.format("  database=%s, schema=%s, table=%s, alias=%s",
      qualified.database or "nil",
      qualified.schema or "nil",
      qualified.table or "nil",
      qualified.alias or "nil"))
  end
end

return TokenContext
