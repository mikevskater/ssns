---Qualified name parsing utilities
---Functions for parsing multi-part identifiers like db.schema.table
---@module ssns.completion.context.common.qualified_names
local QualifiedNames = {}

local Tokens = require('nvim-ssns.completion.tokens')

---@class QualifiedName
---@field database string? Database name (for db.schema.table)
---@field schema string? Schema name (for schema.table or db.schema.table)
---@field table string? Table/view/object name
---@field column string? Column name (for table.column)
---@field alias string? Could be alias or identifier
---@field parts string[] All parts in order (first to last)
---@field has_trailing_dot boolean Whether there's a dot at the end (schema. triggers completion)

---Parse a qualified name from tokens before cursor
---Handles patterns like: dbo.Table, [schema].[table], db.schema.table, alias.column
---@param tokens Token[] Tokens before cursor (most recent first from get_tokens_before_cursor)
---@return QualifiedName qualified Parsed qualified name info
function QualifiedNames.parse_from_tokens(tokens)
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
---Also handles cases where user is typing a partial identifier after a dot (e.g., "TEST.dbo.R█")
---@param tokens Token[] All tokens
---@param line number Cursor line
---@param col number Cursor column
---@return boolean is_after_dot True if cursor is directly after a dot
---@return QualifiedName? qualified Parsed qualified name if in qualified context
function QualifiedNames.is_dot_triggered(tokens, line, col)
  -- Get tokens before cursor
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 7)
  if #prev_tokens == 0 then
    return false, nil
  end

  -- Check if most recent non-whitespace token is a dot
  local first_token = prev_tokens[1]
  if first_token.type == "dot" then
    local qualified = QualifiedNames.parse_from_tokens(prev_tokens)
    return true, qualified
  end

  -- Check if user is typing a partial identifier after a dot (e.g., "TEST.dbo.R█")
  -- Pattern: identifier followed by dot
  if (first_token.type == "identifier" or first_token.type == "bracket_id") and
     #prev_tokens >= 2 and prev_tokens[2].type == "dot" then
    -- Parse qualified name from tokens (skipping the partial identifier being typed)
    local qualified = QualifiedNames.parse_from_tokens(prev_tokens)
    -- Note: The partial identifier is included in parts, but we return is_after_dot=false
    -- to indicate the user is typing (not just triggered by dot)
    -- However, caller can still use the qualified info for filtering
    return false, qualified
  end

  return false, nil
end

---Get the table/alias reference before a dot for qualified column completion
---Handles patterns like: "e." -> "e", "dbo.Employees." -> "dbo.Employees", "e.First" -> "e"
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? reference The table/alias reference, or nil
function QualifiedNames.get_reference_before_dot(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 10)
  if #prev_tokens == 0 then
    return nil
  end

  local i = 1

  -- If current token is an identifier (partial column name), skip it
  local token_at = Tokens.get_token_at_position(tokens, line, col)
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

---Extract the left-side column from a comparison expression
---Parses patterns like "t1.col = " or "column >= " from before cursor
---Used for type-aware column completion on the right side
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return table|nil left_side {qualified: string, table_ref: string|nil, column_name: string, schema: string|nil}
function QualifiedNames.extract_left_side_column(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 15)
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

---Extract prefix and trigger character using token analysis
---@param tokens Token[] Parsed tokens
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string prefix The partial word being typed
---@return string? trigger Trigger character (".", "[", " ", or nil)
function QualifiedNames.extract_prefix_and_trigger(tokens, line, col)
  local token_at, _ = Tokens.get_token_at_position(tokens, line, col)
  local prev_tokens = Tokens.get_tokens_before_cursor(tokens, line, col, 3)

  local trigger = nil

  -- Check the most recent token for trigger characters
  if #prev_tokens > 0 then
    local first_token = prev_tokens[1]
    if first_token.type == "dot" then
      trigger = "."
    elseif first_token.type == "paren_open" then
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
      prefix = Tokens.extract_prefix(token_at, line, col)
    end
  end

  return prefix, trigger
end

return QualifiedNames
