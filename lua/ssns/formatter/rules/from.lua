---@class FromRule
---@field name string Rule name
---FROM/JOIN clause formatting rules.
---Handles table references, JOIN positioning, ON clause formatting.
local From = {
  name = "from",
}

---Check if token is FROM keyword
---@param token table
---@return boolean
function From.is_from(token)
  return token.type == "keyword" and string.upper(token.text) == "FROM"
end

---Check if token is a JOIN type keyword
---@param token table
---@return boolean
function From.is_join_type(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local join_types = {
    JOIN = true,
    INNER = true,
    LEFT = true,
    RIGHT = true,
    FULL = true,
    CROSS = true,
    OUTER = true,
    NATURAL = true,
  }
  return join_types[upper] == true
end

---Check if token is the JOIN keyword itself
---@param token table
---@return boolean
function From.is_join(token)
  return token.type == "keyword" and string.upper(token.text) == "JOIN"
end

---Check if token is a JOIN modifier (INNER, LEFT, RIGHT, etc.)
---@param token table
---@return boolean
function From.is_join_modifier(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local modifiers = {
    INNER = true,
    LEFT = true,
    RIGHT = true,
    FULL = true,
    CROSS = true,
    OUTER = true,
    NATURAL = true,
  }
  return modifiers[upper] == true
end

---Check if token is ON keyword
---@param token table
---@return boolean
function From.is_on(token)
  return token.type == "keyword" and string.upper(token.text) == "ON"
end

---Check if token is AS keyword
---@param token table
---@return boolean
function From.is_as(token)
  return token.type == "keyword" and string.upper(token.text) == "AS"
end

---Check if token is APPLY keyword (for CROSS APPLY, OUTER APPLY)
---@param token table
---@return boolean
function From.is_apply(token)
  return token.type == "keyword" and string.upper(token.text) == "APPLY"
end

---Check if token ends the FROM clause
---@param token table
---@return boolean
function From.is_from_terminator(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  local terminators = {
    WHERE = true,
    GROUP = true,
    ORDER = true,
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,  -- FOR UPDATE, etc.
  }
  return terminators[upper] == true
end

---Get the full JOIN type string (e.g., "LEFT OUTER JOIN")
---@param tokens table[] All tokens
---@param start_idx number Index of first JOIN-related keyword
---@return string join_type The combined JOIN type
---@return number end_idx Index after the JOIN keyword
function From.get_join_type(tokens, start_idx)
  local parts = {}
  local idx = start_idx

  while idx <= #tokens do
    local token = tokens[idx]
    if From.is_join_type(token) then
      table.insert(parts, string.upper(token.text))
      if From.is_join(token) then
        -- JOIN keyword ends the type
        return table.concat(parts, " "), idx
      end
      idx = idx + 1
    else
      break
    end
  end

  return table.concat(parts, " "), idx - 1
end

---Parse a table reference (table name with optional alias)
---@param tokens table[] All tokens
---@param start_idx number Index to start parsing
---@return table table_ref {name: string, alias: string?, has_as: boolean, end_idx: number}
function From.parse_table_reference(tokens, start_idx)
  local ref = {
    name_tokens = {},
    alias = nil,
    has_as = false,
    end_idx = start_idx,
  }

  local idx = start_idx
  local paren_depth = 0

  -- First, collect the table name (may be schema.table or just table)
  while idx <= #tokens do
    local token = tokens[idx]

    -- Track parenthesis for subqueries
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        -- End of subquery
        table.insert(ref.name_tokens, token)
        idx = idx + 1
        break
      end
    end

    -- End conditions (only at paren_depth 0)
    if paren_depth == 0 then
      if token.type == "comma" then
        break
      elseif From.is_join_type(token) or From.is_from_terminator(token) or From.is_on(token) then
        break
      elseif token.type == "semicolon" then
        break
      end
    end

    -- AS keyword starts alias
    if paren_depth == 0 and From.is_as(token) then
      ref.has_as = true
      idx = idx + 1
      -- Next token is the alias
      if idx <= #tokens then
        local alias_token = tokens[idx]
        if alias_token.type == "identifier" or alias_token.type == "bracket_id" then
          ref.alias = alias_token.text
          idx = idx + 1
        end
      end
      break
    end

    -- If we hit an identifier after the table name (no AS), it's an alias
    if paren_depth == 0 and #ref.name_tokens > 0 and
       (token.type == "identifier" or token.type == "bracket_id") then
      local prev = ref.name_tokens[#ref.name_tokens]
      if prev.type ~= "dot" then
        ref.alias = token.text
        idx = idx + 1
        break
      end
    end

    table.insert(ref.name_tokens, token)
    idx = idx + 1
  end

  ref.end_idx = idx - 1
  return ref
end

---Find all JOINs in the FROM clause
---@param tokens table[] All tokens
---@param from_idx number Index of FROM keyword
---@return table[] joins Array of {type: string, table: table_ref, on_tokens: table[]}
function From.find_joins(tokens, from_idx)
  local joins = {}
  local idx = from_idx + 1

  while idx <= #tokens do
    local token = tokens[idx]

    -- End of FROM clause
    if From.is_from_terminator(token) then
      break
    end
    if token.type == "semicolon" then
      break
    end

    -- Found a JOIN
    if From.is_join_type(token) and (From.is_join(token) or From.is_join_modifier(token)) then
      local join = {
        type = nil,
        table_ref = nil,
        on_tokens = {},
        start_idx = idx,
      }

      -- Get full JOIN type
      join.type, idx = From.get_join_type(tokens, idx)
      idx = idx + 1

      -- Parse table reference
      if idx <= #tokens then
        join.table_ref = From.parse_table_reference(tokens, idx)
        idx = join.table_ref.end_idx + 1
      end

      -- Look for ON clause
      if idx <= #tokens and From.is_on(tokens[idx]) then
        idx = idx + 1 -- Skip ON
        local paren_depth = 0
        while idx <= #tokens do
          local t = tokens[idx]
          if t.type == "paren_open" then
            paren_depth = paren_depth + 1
          elseif t.type == "paren_close" then
            paren_depth = paren_depth - 1
          end

          -- End ON clause at next JOIN or terminator (at depth 0)
          if paren_depth == 0 then
            if From.is_join_type(t) or From.is_from_terminator(t) or t.type == "semicolon" then
              break
            end
          end

          table.insert(join.on_tokens, t)
          idx = idx + 1
        end
      end

      table.insert(joins, join)
    else
      idx = idx + 1
    end
  end

  return joins
end

---Get configuration for FROM clause formatting
---@param config FormatterConfig
---@return table from_config
function From.get_config(config)
  return {
    newline_before_join = config.newline_before_clause or true,
    on_same_line = config.join_on_same_line or false,
    indent_on_clause = not (config.join_on_same_line or false),
  }
end

---Apply formatting to FROM/JOIN clause tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function From.apply(token, context, config)
  -- Add formatting metadata for FROM/JOIN clause handling
  if context.current_clause == "FROM" then
    token.in_from_clause = true
  end

  -- Mark JOIN-related tokens
  if From.is_join_modifier(token) then
    token.is_join_modifier = true
  elseif From.is_join(token) then
    token.is_join_keyword = true
  elseif From.is_on(token) then
    token.is_on_keyword = true
  end

  return token
end

return From
