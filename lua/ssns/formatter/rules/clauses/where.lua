---@class WhereRule
---@field name string Rule name
---WHERE clause formatting rules.
---Handles AND/OR positioning, condition indentation, IN lists, BETWEEN.
local Where = {
  name = "where",
}

---Check if token is WHERE keyword
---@param token table
---@return boolean
function Where.is_where(token)
  return token.type == "keyword" and string.upper(token.text) == "WHERE"
end

---Check if token is AND keyword
---@param token table
---@return boolean
function Where.is_and(token)
  return token.type == "keyword" and string.upper(token.text) == "AND"
end

---Check if token is OR keyword
---@param token table
---@return boolean
function Where.is_or(token)
  return token.type == "keyword" and string.upper(token.text) == "OR"
end

---Check if token is AND or OR
---@param token table
---@return boolean
function Where.is_and_or(token)
  return Where.is_and(token) or Where.is_or(token)
end

---Check if token is NOT keyword
---@param token table
---@return boolean
function Where.is_not(token)
  return token.type == "keyword" and string.upper(token.text) == "NOT"
end

---Check if token is IN keyword
---@param token table
---@return boolean
function Where.is_in(token)
  return token.type == "keyword" and string.upper(token.text) == "IN"
end

---Check if token is BETWEEN keyword
---@param token table
---@return boolean
function Where.is_between(token)
  return token.type == "keyword" and string.upper(token.text) == "BETWEEN"
end

---Check if token is LIKE keyword
---@param token table
---@return boolean
function Where.is_like(token)
  return token.type == "keyword" and string.upper(token.text) == "LIKE"
end

---Check if token is EXISTS keyword
---@param token table
---@return boolean
function Where.is_exists(token)
  return token.type == "keyword" and string.upper(token.text) == "EXISTS"
end

---Check if token is IS keyword
---@param token table
---@return boolean
function Where.is_is(token)
  return token.type == "keyword" and string.upper(token.text) == "IS"
end

---Check if token is NULL keyword
---@param token table
---@return boolean
function Where.is_null(token)
  return token.type == "keyword" and string.upper(token.text) == "NULL"
end

---Check if token ends the WHERE clause
---@param token table
---@return boolean
function Where.is_where_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    GROUP = true,
    ORDER = true,
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,
    LIMIT = true,
    OFFSET = true,
  }
  return terminators[upper] == true
end

---Parse WHERE clause into conditions
---@param tokens table[] All tokens
---@param where_idx number Index of WHERE keyword
---@return table[] conditions Array of {tokens: table[], connector: string?}
function Where.parse_conditions(tokens, where_idx)
  local conditions = {}
  local current = {
    tokens = {},
    connector = nil,
  }
  local paren_depth = 0
  local idx = where_idx + 1

  while idx <= #tokens do
    local token = tokens[idx]

    -- Track parenthesis depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- End of WHERE clause
    if paren_depth == 0 and (Where.is_where_terminator(token) or token.type == "semicolon") then
      if #current.tokens > 0 then
        table.insert(conditions, current)
      end
      break
    end

    -- AND/OR at depth 0 separates conditions
    if paren_depth == 0 and Where.is_and_or(token) then
      if #current.tokens > 0 then
        table.insert(conditions, current)
      end
      current = {
        tokens = {},
        connector = string.upper(token.text),
      }
      idx = idx + 1
    else
      table.insert(current.tokens, token)
      idx = idx + 1
    end
  end

  -- Don't forget the last condition
  if #current.tokens > 0 then
    table.insert(conditions, current)
  end

  return conditions
end

---Check if an IN list should be multi-line
---@param tokens table[] Tokens inside the IN parentheses
---@param max_inline_items number Maximum items before going multi-line
---@return boolean
function Where.should_multiline_in_list(tokens, max_inline_items)
  max_inline_items = max_inline_items or 5
  local item_count = 1

  for _, token in ipairs(tokens) do
    if token.type == "comma" then
      item_count = item_count + 1
    end
  end

  return item_count > max_inline_items
end

---Find the IN list within a condition
---@param tokens table[] Condition tokens
---@return table|nil in_list {start_idx: number, end_idx: number, items: table[]}
function Where.find_in_list(tokens)
  local in_idx = nil

  -- Find IN keyword
  for i, token in ipairs(tokens) do
    if Where.is_in(token) then
      in_idx = i
      break
    end
  end

  if not in_idx then
    return nil
  end

  -- Find the opening paren after IN
  local paren_start = nil
  for i = in_idx + 1, #tokens do
    if tokens[i].type == "paren_open" then
      paren_start = i
      break
    end
  end

  if not paren_start then
    return nil
  end

  -- Find matching close paren
  local paren_depth = 1
  local paren_end = nil
  for i = paren_start + 1, #tokens do
    if tokens[i].type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif tokens[i].type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        paren_end = i
        break
      end
    end
  end

  if not paren_end then
    return nil
  end

  -- Parse items
  local items = {}
  local current_item = {}
  for i = paren_start + 1, paren_end - 1 do
    local token = tokens[i]
    if token.type == "comma" then
      if #current_item > 0 then
        table.insert(items, current_item)
        current_item = {}
      end
    else
      table.insert(current_item, token)
    end
  end
  if #current_item > 0 then
    table.insert(items, current_item)
  end

  return {
    start_idx = paren_start,
    end_idx = paren_end,
    items = items,
  }
end

---Get configuration for WHERE clause formatting
---@param config FormatterConfig
---@return table where_config
function Where.get_config(config)
  return {
    and_or_position = config.and_or_position or "leading", -- "leading" or "trailing"
    indent_conditions = true,
    max_inline_in_items = 5, -- Multi-line IN list if more items
    parenthesis_on_own_line = false, -- For complex conditions
  }
end

---Apply formatting to WHERE clause tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Where.apply(token, context, config)
  -- Add formatting metadata for WHERE clause handling
  if context.current_clause == "WHERE" then
    token.in_where_clause = true
  end

  -- Mark AND/OR tokens
  if Where.is_and(token) then
    token.is_and = true
    token.is_condition_connector = true
  elseif Where.is_or(token) then
    token.is_or = true
    token.is_condition_connector = true
  end

  -- Mark IN keyword
  if Where.is_in(token) then
    token.is_in_keyword = true
  end

  -- Mark BETWEEN keyword
  if Where.is_between(token) then
    token.is_between_keyword = true
  end

  return token
end

return Where
