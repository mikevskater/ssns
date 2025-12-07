---@class IndentationRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Indentation rules for SQL formatting.
local Indentation = {
  name = "indentation",
}

---Keywords that increase indentation
local INDENT_INCREASE = {
  SELECT = true,
  FROM = true,
  WHERE = true,
  ["GROUP BY"] = true,
  ["ORDER BY"] = true,
  HAVING = true,
  SET = true,
  VALUES = true,
  CASE = true,
  WHEN = true,
}

---Keywords that decrease indentation
local INDENT_DECREASE = {
  END = true,
  ELSE = true,
}

---Check if token should increase indent level
---@param token Token
---@return boolean
function Indentation.should_increase(token)
  if token.type ~= "keyword" then
    return false
  end
  return INDENT_INCREASE[string.upper(token.text)] == true
end

---Check if token should decrease indent level
---@param token Token
---@return boolean
function Indentation.should_decrease(token)
  if token.type ~= "keyword" then
    return false
  end
  return INDENT_DECREASE[string.upper(token.text)] == true
end

---Calculate indent level for a token based on context
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return number
function Indentation.calculate_level(token, context, config)
  local level = context.indent_level

  -- Subqueries get additional indent
  if context.in_subquery then
    level = level + config.subquery_indent
  end

  -- CASE/WHEN blocks
  if token.type == "keyword" then
    local upper = string.upper(token.text)
    if upper == "WHEN" or upper == "ELSE" then
      level = level + config.case_indent
    elseif upper == "END" then
      level = math.max(0, level - config.case_indent)
    end
  end

  return level
end

---Apply indentation rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Indentation.apply(token, context, config)
  -- Calculate and attach indent level to token
  token.indent_level = Indentation.calculate_level(token, context, config)
  return token
end

return Indentation
