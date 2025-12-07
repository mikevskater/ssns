---@class SpacingRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Whitespace and spacing rules for SQL formatting.
local Spacing = {
  name = "spacing",
}

---Operators that should have spaces around them
local SPACED_OPERATORS = {
  ["="] = true,
  ["<>"] = true,
  ["!="] = true,
  [">="] = true,
  ["<="] = true,
  [">"] = true,
  ["<"] = true,
  ["+"] = true,
  ["-"] = true,
  ["*"] = true,
  ["/"] = true,
  ["%"] = true,
  ["||"] = true,
}

---Check if a token is a spaced operator
---@param token Token
---@return boolean
function Spacing.is_spaced_operator(token)
  if token.type ~= "operator" then
    return false
  end
  return SPACED_OPERATORS[token.text] == true
end

---Determine required whitespace before a token
---@param prev Token|nil Previous token
---@param curr Token Current token
---@param config FormatterConfig
---@return string whitespace
function Spacing.get_before(prev, curr, config)
  if not prev then
    return ""
  end

  -- No space after opening paren (unless configured)
  if prev.type == "paren_open" then
    if config.parenthesis_spacing then
      return " "
    end
    return ""
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    if config.parenthesis_spacing then
      return " "
    end
    return ""
  end

  -- No space around dots (qualified names)
  if prev.type == "dot" or curr.type == "dot" then
    return ""
  end

  -- No space before comma
  if curr.type == "comma" then
    return ""
  end

  -- Space after comma
  if prev.type == "comma" then
    return " "
  end

  -- No space before semicolon
  if curr.type == "semicolon" then
    return ""
  end

  -- Space around operators if configured
  if config.operator_spacing then
    if Spacing.is_spaced_operator(prev) or Spacing.is_spaced_operator(curr) then
      return " "
    end
  end

  -- No space after @
  if prev.type == "at" then
    return ""
  end

  -- Space between word tokens
  local word_types = {
    keyword = true,
    identifier = true,
    bracket_id = true,
    number = true,
    string = true,
    global_variable = true,
    system_procedure = true,
    temp_table = true,
  }

  if word_types[prev.type] and (word_types[curr.type] or curr.type == "star") then
    return " "
  end

  -- Space after star if followed by keyword/identifier
  if prev.type == "star" and word_types[curr.type] then
    return " "
  end

  return ""
end

---Apply spacing rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Spacing.apply(token, context, config)
  -- Spacing is primarily handled in the output generator,
  -- but this can add metadata if needed
  return token
end

return Spacing
