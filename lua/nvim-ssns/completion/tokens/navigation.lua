---Token navigation utilities
---Functions for navigating and searching through token streams
---@module ssns.completion.tokens.navigation
local Navigation = {}

---Get the token at or immediately before a cursor position
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return Token? token Token at or before cursor
---@return number? index Index of the token in the array
function Navigation.get_token_at_position(tokens, line, col)
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
      if token.col < col then
        -- Token starts before cursor
        if token_end_col >= col then
          -- Cursor is within token (e.g., typing in middle of identifier)
          return token, i
        else
          -- Token ends before cursor, remember it as candidate
          best_token = token
          best_index = i
        end
      elseif token.col == col then
        -- Token starts exactly at cursor position
        -- In normal mode (e.g., F2 rename), cursor is ON this character
        -- In insert mode after typing, cursor is after the character
        -- Either way, this is the token the user is interacting with
        return token, i
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
function Navigation.get_tokens_before_cursor(tokens, line, col, count)
  if not tokens or #tokens == 0 then
    return {}
  end

  -- Find the token at/before cursor to get our starting point
  local _, start_index = Navigation.get_token_at_position(tokens, line, col)
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
function Navigation.get_token_after_cursor(tokens, line, col)
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
function Navigation.find_previous_token_of_type(tokens, start_index, token_type)
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
function Navigation.find_previous_keyword(tokens, start_index, keywords)
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

---Check if position is inside a string or comment
---@param tokens Token[] Tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean in_string_or_comment
function Navigation.is_in_string_or_comment(tokens, line, col)
  local token, _ = Navigation.get_token_at_position(tokens, line, col)
  if not token then
    return false
  end

  -- Only consider it "in" a string/comment if the token type matches
  -- AND the cursor is actually within the token's range (not just after it)
  if token.type ~= "string" and token.type ~= "comment" and token.type ~= "line_comment" then
    return false
  end

  -- Check if cursor is within the token's range
  -- get_token_at_position may return a token from a previous line or
  -- one that ends BEFORE the cursor (when cursor is in whitespace)
  if token.line ~= line then
    -- Token is on a different line - for single-line tokens (like line comments),
    -- cursor on a different line is NOT inside the token
    -- For multi-line tokens, we'd need more complex logic, but for now
    -- line_comment tokens are single-line
    if token.type == "line_comment" then
      return false
    end
    -- For block comments, check if the token ends before the cursor line
    -- (simplified: assume single-line block comments for now)
    return false
  end

  -- Same line - check column range
  local token_end_col = token.col + #token.text - 1
  if col > token_end_col then
    -- Cursor is after the end of this token, not inside it
    return false
  end

  return true
end

---Extract prefix (partial word being typed) from cursor position
---@param token Token? Token at cursor (may be partial)
---@param line number Cursor line
---@param col number Cursor column (1-indexed, cursor is BEFORE this column)
---@return string prefix Partial text being typed
function Navigation.extract_prefix(token, line, col)
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

return Navigation
