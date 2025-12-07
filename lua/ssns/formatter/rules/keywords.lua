---@class KeywordsRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Keyword casing rules for SQL formatting.
local Keywords = {
  name = "keywords",
}

---Apply keyword case transformation
---@param text string Keyword text
---@param case_style string "upper"|"lower"|"preserve"
---@return string
function Keywords.apply_case(text, case_style)
  if case_style == "upper" then
    return string.upper(text)
  elseif case_style == "lower" then
    return string.lower(text)
  else
    return text
  end
end

---Check if a token is a keyword that should have casing applied
---@param token Token
---@return boolean
function Keywords.should_transform(token)
  local keyword_types = {
    keyword = true,
    go = true,
  }
  return keyword_types[token.type] == true
end

---Apply keyword casing rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Keywords.apply(token, context, config)
  if Keywords.should_transform(token) then
    token.text = Keywords.apply_case(token.text, config.keyword_case)
  end
  return token
end

return Keywords
