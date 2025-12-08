---@class SelectRule
---@field name string Rule name
---SELECT clause formatting rules.
---Handles column list indentation, alias alignment, function formatting.
local Select = {
  name = "select",
}

---Check if token is SELECT keyword
---@param token table
---@return boolean
function Select.is_select(token)
  return token.type == "keyword" and string.upper(token.text) == "SELECT"
end

---Check if token is TOP keyword
---@param token table
---@return boolean
function Select.is_top(token)
  return token.type == "keyword" and string.upper(token.text) == "TOP"
end

---Check if token is DISTINCT keyword
---@param token table
---@return boolean
function Select.is_distinct(token)
  return token.type == "keyword" and string.upper(token.text) == "DISTINCT"
end

---Check if token is ALL keyword
---@param token table
---@return boolean
function Select.is_all(token)
  return token.type == "keyword" and string.upper(token.text) == "ALL"
end

---Check if token ends the SELECT clause (starts FROM, WHERE, etc.)
---@param token table
---@return boolean
function Select.is_select_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    FROM = true,
    WHERE = true,
    ["GROUP BY"] = true,
    GROUP = true,
    ["ORDER BY"] = true,
    ORDER = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    INTO = true,
  }
  return terminators[upper] == true
end

---Check if token is an aggregate function
---@param token table
---@return boolean
function Select.is_aggregate_function(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local aggregates = {
    COUNT = true,
    SUM = true,
    AVG = true,
    MIN = true,
    MAX = true,
    STRING_AGG = true,
    STDEV = true,
    STDEVP = true,
    VAR = true,
    VARP = true,
  }
  return aggregates[upper] == true
end

---Check if token is a window function
---@param token table
---@return boolean
function Select.is_window_function(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local window_funcs = {
    ROW_NUMBER = true,
    RANK = true,
    DENSE_RANK = true,
    NTILE = true,
    LAG = true,
    LEAD = true,
    FIRST_VALUE = true,
    LAST_VALUE = true,
  }
  return window_funcs[upper] == true
end

---Check if token is AS keyword
---@param token table
---@return boolean
function Select.is_as(token)
  return token.type == "keyword" and string.upper(token.text) == "AS"
end

---Check if token is OVER keyword (for window functions)
---@param token table
---@return boolean
function Select.is_over(token)
  return token.type == "keyword" and string.upper(token.text) == "OVER"
end

---Check if token is CASE keyword
---@param token table
---@return boolean
function Select.is_case(token)
  return token.type == "keyword" and string.upper(token.text) == "CASE"
end

---Check if token is END keyword
---@param token table
---@return boolean
function Select.is_end(token)
  return token.type == "keyword" and string.upper(token.text) == "END"
end

---Find the range of tokens that make up the SELECT list
---@param tokens table[] All tokens
---@param select_idx number Index of SELECT keyword
---@return number start_idx Index of first column token
---@return number end_idx Index of last column token (before terminator)
function Select.find_select_list_range(tokens, select_idx)
  local start_idx = select_idx + 1

  -- Skip past SELECT modifiers (DISTINCT, ALL, TOP n, TOP (n) PERCENT)
  while start_idx <= #tokens do
    local token = tokens[start_idx]
    if Select.is_distinct(token) or Select.is_all(token) then
      start_idx = start_idx + 1
    elseif Select.is_top(token) then
      start_idx = start_idx + 1
      -- Skip the TOP value (number or parenthesized expression)
      if start_idx <= #tokens then
        local next_token = tokens[start_idx]
        if next_token.type == "paren_open" then
          -- Skip until matching close paren
          local paren_depth = 1
          start_idx = start_idx + 1
          while start_idx <= #tokens and paren_depth > 0 do
            if tokens[start_idx].type == "paren_open" then
              paren_depth = paren_depth + 1
            elseif tokens[start_idx].type == "paren_close" then
              paren_depth = paren_depth - 1
            end
            start_idx = start_idx + 1
          end
        elseif next_token.type == "number" then
          start_idx = start_idx + 1
        end
        -- Check for PERCENT
        if start_idx <= #tokens and tokens[start_idx].type == "keyword" and
           string.upper(tokens[start_idx].text) == "PERCENT" then
          start_idx = start_idx + 1
        end
        -- Check for WITH TIES
        if start_idx <= #tokens and tokens[start_idx].type == "keyword" and
           string.upper(tokens[start_idx].text) == "WITH" then
          start_idx = start_idx + 1
          if start_idx <= #tokens and tokens[start_idx].type == "keyword" and
             string.upper(tokens[start_idx].text) == "TIES" then
            start_idx = start_idx + 1
          end
        end
      end
    else
      break
    end
  end

  -- Find where the SELECT list ends
  local end_idx = start_idx
  local paren_depth = 0

  while end_idx <= #tokens do
    local token = tokens[end_idx]

    -- Track parenthesis depth (don't end on terminators inside parens)
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- Check for SELECT list terminator (only at paren_depth 0)
    if paren_depth == 0 and Select.is_select_terminator(token) then
      end_idx = end_idx - 1
      break
    end

    -- Check for semicolon (end of statement)
    if token.type == "semicolon" then
      end_idx = end_idx - 1
      break
    end

    end_idx = end_idx + 1
  end

  -- Clamp to valid range
  if end_idx > #tokens then
    end_idx = #tokens
  end

  return start_idx, end_idx
end

---Parse SELECT list into individual column expressions
---@param tokens table[] All tokens
---@param start_idx number Start of column list
---@param end_idx number End of column list
---@return table[] columns Array of {tokens: table[], alias: string?, has_as: boolean}
function Select.parse_columns(tokens, start_idx, end_idx)
  local columns = {}
  local current_col = {
    tokens = {},
    alias = nil,
    has_as = false,
  }
  local paren_depth = 0
  local case_depth = 0

  for i = start_idx, end_idx do
    local token = tokens[i]

    -- Track nesting depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    elseif Select.is_case(token) then
      case_depth = case_depth + 1
    elseif Select.is_end(token) then
      case_depth = math.max(0, case_depth - 1)
    end

    -- Comma at depth 0 separates columns
    if token.type == "comma" and paren_depth == 0 and case_depth == 0 then
      if #current_col.tokens > 0 then
        table.insert(columns, current_col)
      end
      current_col = {
        tokens = {},
        alias = nil,
        has_as = false,
      }
    else
      table.insert(current_col.tokens, token)

      -- Track AS keyword and alias
      if Select.is_as(token) then
        current_col.has_as = true
      elseif current_col.has_as and not current_col.alias then
        -- Token after AS is the alias
        current_col.alias = token.text
      end
    end
  end

  -- Don't forget the last column
  if #current_col.tokens > 0 then
    table.insert(columns, current_col)
  end

  return columns
end

---Calculate the width of column expression (before AS keyword)
---@param column table Column info from parse_columns
---@return number width Character width before AS
function Select.calculate_expression_width(column)
  local width = 0
  for _, token in ipairs(column.tokens) do
    if Select.is_as(token) then
      break
    end
    width = width + #token.text + 1 -- +1 for potential spacing
  end
  return width > 0 and width - 1 or 0 -- Remove trailing space
end

---Get configuration for SELECT formatting
---@param config FormatterConfig
---@return table select_config
function Select.get_config(config)
  return {
    one_column_per_line = true, -- Put each column on its own line
    align_aliases = config.align_aliases or false,
    indent_columns = true, -- Indent column list
    keep_star_inline = true, -- Keep SELECT * on same line
  }
end

---Check if SELECT list is just a star (SELECT *)
---@param tokens table[] All tokens
---@param start_idx number Start of column list
---@param end_idx number End of column list
---@return boolean
function Select.is_select_star(tokens, start_idx, end_idx)
  -- Single star token
  if start_idx == end_idx and tokens[start_idx].type == "star" then
    return true
  end

  -- table.* pattern (3 tokens: identifier, dot, star)
  if end_idx - start_idx == 2 then
    local t1 = tokens[start_idx]
    local t2 = tokens[start_idx + 1]
    local t3 = tokens[start_idx + 2]
    if (t1.type == "identifier" or t1.type == "bracket_id") and
       t2.type == "dot" and t3.type == "star" then
      return true
    end
  end

  return false
end

---Apply formatting to SELECT clause tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Select.apply(token, context, config)
  -- Add formatting metadata for SELECT clause handling
  if context.current_clause == "SELECT" then
    token.in_select_clause = true
  end
  return token
end

return Select
