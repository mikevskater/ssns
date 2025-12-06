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

---Extract the left-side column from a comparison expression
---Parses patterns like "t1.col = " or "column >= " from before cursor
---Used for type-aware column completion on the right side
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return table|nil left_side {qualified: string, table_ref: string|nil, column_name: string, schema: string|nil}
function TokenContext.extract_left_side_column(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 15)
  if #prev_tokens == 0 then
    return nil
  end

  local i = 1

  -- Skip any partial identifier at cursor position
  if prev_tokens[i] and (prev_tokens[i].type == "identifier" or prev_tokens[i].type == "bracket_id") then
    -- Check if this is a partial token at cursor
    local token = prev_tokens[i]
    if token.line == line and token.col < col and token.col + #token.text >= col then
      i = i + 1
    end
  end

  -- Look for operator token
  local found_operator = false
  while i <= #prev_tokens do
    local token = prev_tokens[i]
    if token.type == "operator" then
      found_operator = true
      i = i + 1
      break
    end
    i = i + 1
    -- Don't look too far back
    if i > 5 then
      return nil
    end
  end

  if not found_operator then
    return nil
  end

  -- Now collect the qualified name before the operator
  local parts = {}
  while i <= #prev_tokens do
    local token = prev_tokens[i]
    if token.type == "identifier" or token.type == "bracket_id" then
      local name = token.text
      if token.type == "bracket_id" then
        name = name:sub(2, -2)  -- Remove [ and ]
      end
      table.insert(parts, 1, name)  -- Insert at beginning (reverse order)
      i = i + 1

      -- Check for preceding dot
      if i <= #prev_tokens and prev_tokens[i].type == "dot" then
        i = i + 1
        -- Continue collecting
      else
        break
      end
    elseif token.type == "keyword" then
      -- Stop at keyword (AND, OR, WHERE, etc.)
      break
    else
      break
    end
  end

  if #parts == 0 then
    return nil
  end

  -- Build result
  local qualified = table.concat(parts, ".")
  if #parts == 1 then
    -- Unqualified column: "column = "
    return {
      qualified = qualified,
      table_ref = nil,
      column_name = parts[1],
    }
  elseif #parts == 2 then
    -- Qualified: "alias.column = " or "table.column = "
    return {
      qualified = qualified,
      table_ref = parts[1],
      column_name = parts[2],
    }
  elseif #parts >= 3 then
    -- Schema qualified: "schema.table.column = "
    return {
      qualified = qualified,
      table_ref = parts[#parts - 1],  -- table
      column_name = parts[#parts],     -- column
      schema = parts[#parts - 2],      -- schema
    }
  end

  return nil
end

---Get the table/alias reference before a dot for qualified column completion
---Handles patterns like: "e." -> "e", "dbo.Employees." -> "dbo.Employees", "e.First" -> "e"
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? reference The table/alias reference, or nil
function TokenContext.get_reference_before_dot(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 10)
  if #prev_tokens == 0 then
    return nil
  end

  local i = 1

  -- If current token is an identifier (partial column name), skip it
  local token_at = TokenContext.get_token_at_position(tokens, line, col)
  if token_at and (token_at.type == "identifier" or token_at.type == "bracket_id") then
    -- Check if cursor is within this token (partial typing)
    if token_at.line == line and token_at.col < col then
      -- Skip this partial identifier - it's the column being typed
      i = 2  -- Start from second token in prev_tokens (since first is the partial)
    end
  end

  -- Now look for dot followed by identifier(s)
  if i <= #prev_tokens and prev_tokens[i].type == "dot" then
    -- We're after a dot - collect the qualified name before it
    i = i + 1
    local parts = {}

    while i <= #prev_tokens do
      local token = prev_tokens[i]
      if token.type == "identifier" or token.type == "bracket_id" then
        local name = token.text
        if token.type == "bracket_id" then
          name = name:sub(2, -2)  -- Remove [ and ]
        end
        table.insert(parts, 1, name)  -- Insert at beginning (reverse order)
        i = i + 1

        -- Check for preceding dot
        if i <= #prev_tokens and prev_tokens[i].type == "dot" then
          i = i + 1
          -- Continue collecting
        else
          break
        end
      else
        break
      end
    end

    if #parts > 0 then
      return table.concat(parts, ".")
    end
  end

  return nil
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

---Detect TABLE context from tokens
---Replaces regex patterns for FROM, JOIN, UPDATE, DELETE, INSERT INTO, TRUNCATE, ALTER, MERGE, USING
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("table" or nil if not table context)
---@return string? mode Sub-mode for provider routing (from, join, update, delete, insert, etc.)
---@return table extra Extra context info (filter_schema, filter_database, etc.)
function TokenContext.detect_table_context_from_tokens(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 10)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find the most recent keyword in the token stream
  local keyword_token = nil
  local keyword_idx = nil
  local second_keyword_token = nil
  local second_keyword_idx = nil

  for i, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      if not keyword_token then
        keyword_token = t
        keyword_idx = i
      elseif not second_keyword_token then
        second_keyword_token = t
        second_keyword_idx = i
        break
      end
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()
  local second_kw = second_keyword_token and second_keyword_token.text:upper() or nil

  -- Check for qualified name after keyword using token-based detection
  local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)

  -- Helper to set qualified name extra fields
  local function set_qualified_extra(qual)
    if qual.database then
      extra.database = qual.database
      extra.schema = qual.schema
      extra.filter_database = qual.database
      extra.filter_schema = qual.schema
      extra.omit_schema = true
    elseif qual.schema then
      extra.potential_database = qual.schema
      extra.schema = qual.schema
      extra.filter_schema = qual.schema
      extra.omit_schema = true
    end
  end

  -- FROM detection
  if kw == "FROM" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "from_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "from_qualified", extra
      end
    end
    return "table", "from", extra
  end

  -- JOIN detection (including modifiers)
  -- Patterns: JOIN, INNER JOIN, LEFT JOIN, LEFT OUTER JOIN, RIGHT JOIN, etc.
  if kw == "JOIN" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "join_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "join_qualified", extra
      end
    end
    return "table", "join", extra
  end

  -- Check for JOIN modifiers (INNER, LEFT, RIGHT, FULL, CROSS, OUTER followed by JOIN)
  if (kw == "INNER" or kw == "LEFT" or kw == "RIGHT" or kw == "FULL" or kw == "CROSS" or kw == "OUTER") then
    -- Look for JOIN as the next keyword
    if second_kw == "JOIN" then
      return "table", "join", extra
    end
    -- Could also be "LEFT OUTER JOIN" or "RIGHT OUTER JOIN" or "FULL OUTER JOIN"
    -- In that case, kw is OUTER and we need to check if there's JOIN before it
    -- But if kw is one of LEFT/RIGHT/FULL and we didn't find JOIN, check next tokens
    -- Actually, with "LEFT OUTER JOIN", the token order would be JOIN, OUTER, LEFT
    -- So if kw is LEFT and second_kw is OUTER, we need to check if there's a JOIN
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "JOIN" then
        return "table", "join", extra
      elseif t.type == "keyword" then
        break -- Stop at any other keyword
      end
    end
  end

  -- UPDATE detection
  if kw == "UPDATE" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
    end
    return "table", "update", extra
  end

  -- DELETE detection
  -- Patterns: DELETE FROM, DELETE (without FROM)
  if kw == "DELETE" then
    return "table", "delete", extra
  end
  if kw == "FROM" and second_kw == "DELETE" then
    return "table", "delete", extra
  end

  -- TRUNCATE TABLE detection
  if kw == "TABLE" and second_kw == "TRUNCATE" then
    return "table", "truncate", extra
  end

  -- ALTER TABLE detection
  if kw == "TABLE" and second_kw == "ALTER" then
    return "table", "alter", extra
  end

  -- INSERT INTO detection
  if kw == "INTO" and second_kw == "INSERT" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
    end
    return "table", "insert", extra
  end

  -- MERGE INTO detection
  if kw == "INTO" and second_kw == "MERGE" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
    end
    return "table", "merge", extra
  end

  -- MERGE USING detection
  if kw == "USING" then
    if is_after_dot and qualified then
      set_qualified_extra(qualified)
      if qualified.database then
        return "table", "merge_cross_db_qualified", extra
      elseif qualified.schema then
        return "table", "merge_qualified", extra
      end
    end
    return "table", "merge", extra
  end

  return nil, nil, extra
end

---Detect COLUMN context from tokens
---Replaces regex patterns for SELECT, WHERE, ON, SET, OUTPUT, ORDER BY, GROUP BY, HAVING
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not column context)
---@return string? mode Sub-mode for provider routing (select, where, on, set, etc.)
---@return table extra Extra context info (table_ref, left_side, etc.)
function TokenContext.detect_column_context_from_tokens(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 15)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- First check for qualified column reference (alias.column pattern)
  local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)
  if is_after_dot and qualified then
    -- Check if this is a table qualifier (for column completion)
    -- vs a schema qualifier (for table completion) - handled by TABLE detection
    local ref = TokenContext.get_reference_before_dot(tokens, line, col)
    if ref then
      extra.table_ref = ref
      extra.filter_table = ref
      extra.omit_table = true
      return "column", "qualified", extra
    end
  end

  -- Find the most recent keywords in the token stream
  local keyword_token = nil
  local keyword_idx = nil
  local second_keyword_token = nil

  for i, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      if not keyword_token then
        keyword_token = t
        keyword_idx = i
      elseif not second_keyword_token then
        second_keyword_token = t
        break
      end
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()
  local second_kw = second_keyword_token and second_keyword_token.text:upper() or nil

  -- SELECT detection (check that there's no FROM after SELECT)
  if kw == "SELECT" then
    -- Check if there's a FROM keyword between SELECT and cursor
    for i = keyword_idx - 1, 1, -1 do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "FROM" then
        -- There's a FROM, so we're not in SELECT clause
        break
      end
    end
    return "column", "select", extra
  end

  -- Subquery SELECT detection: (SELECT ...
  -- Look for lparen before SELECT
  if kw == "SELECT" then
    -- Check for opening paren indicating subquery
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "lparen" then
        -- This is a subquery SELECT
        return "column", "select", extra
      elseif t.type == "keyword" then
        break
      end
    end
  end

  -- WHERE detection
  if kw == "WHERE" then
    -- Check for left-side of comparison (type-aware completion)
    local left_side = TokenContext.extract_left_side_column(tokens, line, col)
    if left_side then
      extra.left_side = left_side
    end
    return "column", "where", extra
  end

  -- AND/OR detection (could be in WHERE clause)
  if kw == "AND" or kw == "OR" then
    return "column", "where", extra
  end

  -- ON detection (JOIN condition)
  if kw == "ON" then
    local left_side = TokenContext.extract_left_side_column(tokens, line, col)
    if left_side then
      extra.left_side = left_side
    end
    return "column", "on", extra
  end

  -- SET detection (UPDATE SET clause)
  if kw == "SET" then
    return "column", "set", extra
  end

  -- ORDER BY detection
  if kw == "BY" and second_kw == "ORDER" then
    return "column", "order_by", extra
  end

  -- GROUP BY detection
  if kw == "BY" and second_kw == "GROUP" then
    return "column", "group_by", extra
  end

  -- HAVING detection
  if kw == "HAVING" then
    return "column", "having", extra
  end

  -- OUTPUT detection
  if kw == "OUTPUT" then
    extra.is_output_clause = true
    return "column", "output", extra
  end

  -- Check for OUTPUT inserted./deleted. pattern
  if kw == "INSERTED" or kw == "DELETED" then
    -- Check if previous keyword is OUTPUT (or if there's OUTPUT before)
    for i = keyword_idx + 1, #prev_tokens do
      local t = prev_tokens[i]
      if t.type == "keyword" and t.text:upper() == "OUTPUT" then
        extra.is_output_clause = true
        extra.output_pseudo_table = kw:lower()
        extra.table_ref = kw:lower()
        return "column", "output", extra
      end
    end
  end

  return nil, nil, extra
end

---Detect PROCEDURE/DATABASE/SCHEMA context from tokens
---Replaces regex patterns for EXEC/EXECUTE and USE
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("procedure", "database", "schema", or nil)
---@return string? mode Sub-mode for provider routing
---@return table extra Extra context info
function TokenContext.detect_other_context_from_tokens(tokens, line, col)
  local prev_tokens = TokenContext.get_tokens_before_cursor(tokens, line, col, 5)
  if #prev_tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Find the most recent keyword
  local keyword_token = nil
  for _, t in ipairs(prev_tokens) do
    if t.type == "keyword" then
      keyword_token = t
      break
    end
  end

  if not keyword_token then
    return nil, nil, extra
  end

  local kw = keyword_token.text:upper()

  -- EXEC/EXECUTE detection (procedure context)
  if kw == "EXEC" or kw == "EXECUTE" then
    return "procedure", "exec", extra
  end

  -- USE detection (database context)
  if kw == "USE" then
    -- Check if there's a qualified name (db.schema)
    local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)
    if is_after_dot and qualified and qualified.database then
      extra.database = qualified.database
      return "schema", "cross_db", extra
    end
    return "database", "use", extra
  end

  return nil, nil, extra
end

---Detect VALUES clause context from tokens
---Handles patterns like: VALUES (val1, |val2) with position tracking for type-aware completion
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in VALUES)
---@return string? mode Sub-mode for provider routing ("values" or nil)
---@return table extra Extra context info (value_position for column position)
function TokenContext.detect_values_context_from_tokens(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- We need to find the pattern: VALUES ( ... cursor ... )
  -- Walk through tokens to find VALUES keyword, then track parens and commas

  -- Find cursor position in token stream
  local _, cursor_idx = TokenContext.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    -- Cursor might be after last token, try to find nearby tokens
    cursor_idx = #tokens
  end

  -- Look backwards for VALUES keyword
  local values_idx = nil
  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" and t.text:upper() == "VALUES" then
      values_idx = i
      break
    end
    -- Stop if we hit SELECT/INSERT/UPDATE/DELETE (past the VALUES clause)
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "SELECT" or kw == "INSERT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" then
        break
      end
    end
  end

  if not values_idx then
    return nil, nil, {}
  end

  -- Now verify cursor is inside a VALUES paren group
  -- Track paren depth from VALUES to cursor
  local paren_depth = 0
  local value_position = 0
  local found_values_paren = false
  local in_current_row = false

  for i = values_idx + 1, #tokens do
    local t = tokens[i]

    -- Check if we've passed the cursor position
    if t.line > line or (t.line == line and t.col >= col) then
      -- Cursor is before this token
      if in_current_row then
        extra.value_position = value_position
        return "column", "values", extra
      end
      break
    end

    if t.type == "lparen" then
      paren_depth = paren_depth + 1
      if paren_depth == 1 then
        found_values_paren = true
        in_current_row = true
        value_position = 0  -- Reset for new row (multi-row VALUES)
      end
    elseif t.type == "rparen" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        in_current_row = false
      end
    elseif t.type == "comma" and paren_depth == 1 then
      -- Comma at depth 1 = separator between values in row
      value_position = value_position + 1
    end
  end

  -- If we're still inside VALUES parens at cursor position
  if found_values_paren and in_current_row then
    extra.value_position = value_position
    return "column", "values", extra
  end

  return nil, nil, {}
end

---Detect INSERT column list context from tokens
---Handles patterns like: INSERT INTO table (col1, |col2) for column completion
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in INSERT column list)
---@return string? mode Sub-mode for provider routing ("insert_columns" or nil)
---@return table extra Extra context info (insert_table, insert_schema)
function TokenContext.detect_insert_columns_from_tokens(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- We need to find: INSERT INTO table_name ( ... cursor ... ) VALUES
  -- The column list is between the first ( after table name and VALUES keyword

  -- Find cursor position in token stream
  local _, cursor_idx = TokenContext.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for INSERT keyword
  local insert_idx = nil
  local into_idx = nil
  local table_tokens = {}
  local lparen_idx = nil

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "VALUES" then
        -- VALUES keyword found - we might be in column list before it
        -- Don't break, continue looking for INSERT
      elseif kw == "INTO" and not into_idx then
        into_idx = i
      elseif kw == "INSERT" and into_idx then
        insert_idx = i
        break
      elseif kw == "SELECT" or kw == "UPDATE" or kw == "DELETE" or kw == "MERGE" then
        -- Different statement type
        break
      end
    end
  end

  if not insert_idx or not into_idx then
    return nil, nil, {}
  end

  -- Now collect table name tokens after INTO
  -- Pattern: INTO [identifier] [dot identifier]* [lparen]
  local i = into_idx + 1
  while i <= #tokens do
    local t = tokens[i]
    if t.type == "identifier" or t.type == "bracket_id" then
      table.insert(table_tokens, t)
      i = i + 1
    elseif t.type == "dot" then
      -- Part of qualified name
      i = i + 1
    elseif t.type == "lparen" then
      lparen_idx = i
      break
    elseif t.type == "keyword" then
      -- Unexpected keyword - no column list paren
      break
    else
      i = i + 1
    end
  end

  if not lparen_idx or #table_tokens == 0 then
    return nil, nil, {}
  end

  -- Check if cursor is between lparen and VALUES (or rparen)
  -- Find the matching rparen or VALUES keyword after lparen
  local rparen_idx = nil
  local values_idx = nil
  local paren_depth = 1

  for j = lparen_idx + 1, #tokens do
    local t = tokens[j]
    if t.type == "lparen" then
      paren_depth = paren_depth + 1
    elseif t.type == "rparen" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        rparen_idx = j
        break
      end
    elseif t.type == "keyword" and t.text:upper() == "VALUES" then
      values_idx = j
      break
    end
  end

  -- Check if cursor is within the column list
  local lparen_token = tokens[lparen_idx]
  local cursor_after_lparen = line > lparen_token.line or
    (line == lparen_token.line and col > lparen_token.col)

  local cursor_before_end = true
  if rparen_idx then
    local rparen_token = tokens[rparen_idx]
    cursor_before_end = line < rparen_token.line or
      (line == rparen_token.line and col <= rparen_token.col)
  elseif values_idx then
    local values_token = tokens[values_idx]
    cursor_before_end = line < values_token.line or
      (line == values_token.line and col < values_token.col)
  end

  if cursor_after_lparen and cursor_before_end then
    -- We're in the INSERT column list! Extract table info
    local parts = {}
    for _, t in ipairs(table_tokens) do
      local name = t.text
      if t.type == "bracket_id" then
        name = name:sub(2, -2)  -- Remove [ and ]
      end
      table.insert(parts, name)
    end

    if #parts >= 2 then
      extra.insert_schema = parts[#parts - 1]
      extra.insert_table = parts[#parts]
      extra.schema = extra.insert_schema
      extra.table = extra.insert_table
    elseif #parts == 1 then
      extra.insert_table = parts[1]
      extra.table = extra.insert_table
    end

    return "column", "insert_columns", extra
  end

  return nil, nil, {}
end

---Detect MERGE INSERT column list context from tokens
---Handles patterns like: WHEN NOT MATCHED THEN INSERT (col1, |col2)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? ctx_type Context type ("column" or nil if not in MERGE INSERT)
---@return string? mode Sub-mode for provider routing ("merge_insert_columns" or nil)
---@return table extra Extra context info (is_merge_insert flag)
function TokenContext.detect_merge_insert_from_tokens(tokens, line, col)
  if not tokens or #tokens == 0 then
    return nil, nil, {}
  end

  local extra = {}

  -- Pattern: WHEN NOT MATCHED THEN INSERT ( ... cursor ... )
  -- Find cursor position
  local _, cursor_idx = TokenContext.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards for pattern: WHEN NOT MATCHED THEN INSERT (
  local found_lparen = false
  local found_insert = false
  local found_then = false
  local found_matched = false
  local found_not = false
  local found_when = false
  local lparen_idx = nil

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "lparen" and not found_lparen then
      found_lparen = true
      lparen_idx = i
    elseif t.type == "keyword" then
      local kw = t.text:upper()
      if kw == "INSERT" and found_lparen and not found_insert then
        found_insert = true
      elseif kw == "THEN" and found_insert and not found_then then
        found_then = true
      elseif kw == "MATCHED" and found_then and not found_matched then
        found_matched = true
      elseif kw == "NOT" and found_matched and not found_not then
        found_not = true
      elseif kw == "WHEN" and found_not and not found_when then
        found_when = true
        break
      elseif kw == "MERGE" then
        -- Found MERGE before completing the pattern - stop
        break
      elseif kw == "VALUES" then
        -- We've hit VALUES - we're past the column list
        return nil, nil, {}
      end
    elseif t.type == "rparen" and found_lparen then
      -- Closed paren before we found the pattern - cursor not in column list
      return nil, nil, {}
    end
  end

  if found_when and found_not and found_matched and found_then and found_insert and lparen_idx then
    -- Verify cursor is after the lparen
    local lparen_token = tokens[lparen_idx]
    if line > lparen_token.line or (line == lparen_token.line and col > lparen_token.col) then
      extra.is_merge_insert = true
      return "column", "merge_insert_columns", extra
    end
  end

  return nil, nil, {}
end

---Detect if cursor is inside a subquery SELECT clause
---Handles patterns like: WHERE col IN (SELECT |column FROM table)
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return boolean in_subquery_select True if in subquery SELECT clause
---@return table extra Extra context info
function TokenContext.is_in_subquery_select(tokens, line, col)
  if not tokens or #tokens == 0 then
    return false, {}
  end

  -- Find cursor position
  local _, cursor_idx = TokenContext.get_token_at_position(tokens, line, col)
  if not cursor_idx then
    cursor_idx = #tokens
  end

  -- Look backwards tracking paren depth
  -- We're in a subquery SELECT if:
  -- 1. There's a ( before us
  -- 2. Followed by SELECT
  -- 3. No FROM after the SELECT (between SELECT and cursor)
  local paren_depth = 0
  local found_select_in_subquery = false
  local select_idx = nil

  for i = cursor_idx, 1, -1 do
    local t = tokens[i]
    if t.type == "rparen" then
      paren_depth = paren_depth + 1
    elseif t.type == "lparen" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        -- We're inside a paren group - look for SELECT after this
        for j = i + 1, cursor_idx do
          local t2 = tokens[j]
          if t2.type == "keyword" then
            local kw = t2.text:upper()
            if kw == "SELECT" then
              found_select_in_subquery = true
              select_idx = j
            elseif kw == "FROM" and found_select_in_subquery then
              -- There's a FROM after SELECT - not in SELECT clause
              found_select_in_subquery = false
            end
          end
        end
        break
      end
    end
  end

  return found_select_in_subquery, {}
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
