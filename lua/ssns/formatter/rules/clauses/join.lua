---@class JoinRule
---@field name string Rule name
---JOIN clause formatting rules.
---Handles JOIN types, ON clause positioning, multi-condition ON formatting.
local Join = {
  name = "join",
}

-- =============================================================================
-- JOIN Type Detection
-- =============================================================================

---Check if token is a JOIN type keyword (JOIN, INNER, LEFT, RIGHT, etc.)
---@param token table
---@return boolean
function Join.is_join_type(token)
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
function Join.is_join(token)
  return token.type == "keyword" and string.upper(token.text) == "JOIN"
end

---Check if token is a JOIN modifier (INNER, LEFT, RIGHT, etc.)
---@param token table
---@return boolean
function Join.is_join_modifier(token)
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
function Join.is_on(token)
  return token.type == "keyword" and string.upper(token.text) == "ON"
end

---Check if token is APPLY keyword (for CROSS APPLY, OUTER APPLY)
---@param token table
---@return boolean
function Join.is_apply(token)
  return token.type == "keyword" and string.upper(token.text) == "APPLY"
end

---Check if token is AND keyword (for ON conditions)
---@param token table
---@return boolean
function Join.is_and(token)
  return token.type == "keyword" and string.upper(token.text) == "AND"
end

---Check if token is OR keyword (for ON conditions)
---@param token table
---@return boolean
function Join.is_or(token)
  return token.type == "keyword" and string.upper(token.text) == "OR"
end

-- =============================================================================
-- JOIN Parsing
-- =============================================================================

---Get the full JOIN type string (e.g., "LEFT OUTER JOIN")
---@param tokens table[] All tokens
---@param start_idx number Index of first JOIN-related keyword
---@return string join_type The combined JOIN type
---@return number end_idx Index after the JOIN keyword
function Join.get_join_type(tokens, start_idx)
  local parts = {}
  local idx = start_idx

  while idx <= #tokens do
    local token = tokens[idx]
    if Join.is_join_type(token) then
      table.insert(parts, string.upper(token.text))
      if Join.is_join(token) then
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

---Normalize JOIN keyword to full or short form
---@param join_type string The JOIN type string (e.g., "INNER JOIN", "LEFT OUTER JOIN")
---@param style string "full"|"short" - Whether to use full or short form
---@return string normalized The normalized JOIN type
function Join.normalize_join_keyword(join_type, style)
  if style == "short" then
    -- Remove redundant keywords: INNER JOIN -> JOIN, LEFT OUTER JOIN -> LEFT JOIN
    local normalized = join_type
    normalized = normalized:gsub("INNER ", "")
    normalized = normalized:gsub(" OUTER", "")
    return normalized
  else
    -- Full form: ensure INNER is present for plain JOIN
    if join_type == "JOIN" then
      return "INNER JOIN"
    end
    -- Ensure OUTER is present for LEFT/RIGHT/FULL
    if join_type == "LEFT JOIN" then
      return "LEFT OUTER JOIN"
    elseif join_type == "RIGHT JOIN" then
      return "RIGHT OUTER JOIN"
    elseif join_type == "FULL JOIN" then
      return "FULL OUTER JOIN"
    end
    return join_type
  end
end

---Parse ON clause conditions
---@param tokens table[] ON clause tokens (after ON keyword)
---@return table[] conditions Array of {tokens: table[], connector: string?}
function Join.parse_on_conditions(tokens)
  local conditions = {}
  local current = {
    tokens = {},
    connector = nil,
  }
  local paren_depth = 0

  for _, token in ipairs(tokens) do
    -- Track parenthesis depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- AND/OR at depth 0 separates conditions
    if paren_depth == 0 and (Join.is_and(token) or Join.is_or(token)) then
      if #current.tokens > 0 then
        table.insert(conditions, current)
      end
      current = {
        tokens = {},
        connector = string.upper(token.text),
      }
    else
      table.insert(current.tokens, token)
    end
  end

  -- Don't forget the last condition
  if #current.tokens > 0 then
    table.insert(conditions, current)
  end

  return conditions
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for JOIN clause formatting
---@param config FormatterConfig
---@return table join_config
function Join.get_config(config)
  return {
    -- Existing config options
    on_same_line = config.join_on_same_line or false,

    -- Phase 1 new config options
    join_newline = config.join_newline ~= false,              -- default true
    keyword_style = config.join_keyword_style or "full",       -- "full"|"short"
    indent_style = config.join_indent_style or "indent",       -- "align"|"indent"
    on_condition_style = config.on_condition_style or "inline", -- "inline"|"stacked"
    on_and_position = config.on_and_position or "leading",     -- "leading"|"trailing"
    cross_apply_newline = config.cross_apply_newline ~= false, -- default true
    empty_line_before_join = config.empty_line_before_join or false,
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to JOIN clause tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Join.apply(token, context, config)
  local join_config = Join.get_config(config)

  -- Mark JOIN-related tokens
  if Join.is_join_modifier(token) then
    token.is_join_modifier = true
  elseif Join.is_join(token) then
    token.is_join_keyword = true
    token.join_keyword_style = join_config.keyword_style
  elseif Join.is_on(token) then
    token.is_on_keyword = true
    token.on_same_line = join_config.on_same_line
  elseif Join.is_apply(token) then
    token.is_apply_keyword = true
    token.cross_apply_newline = join_config.cross_apply_newline
  end

  -- Mark AND/OR in ON clause context
  if context.current_clause == "ON" or context.in_on_clause then
    if Join.is_and(token) or Join.is_or(token) then
      token.is_on_condition_connector = true
      token.on_and_position = join_config.on_and_position
    end
  end

  return token
end

return Join
