---@class CasingPass
---Pass 1: Apply casing rules to keywords, functions, and datatypes
---This pass modifies token.text to have the correct case based on config.
---
---Annotations added:
---  token.original_text  - preserves original text before casing
---  token.casing_applied - true if casing was applied to this token
local CasingPass = {}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Apply case transformation to text
---@param text string The text to transform
---@param case_style string "upper"|"lower"|"preserve"
---@return string
local function apply_case(text, case_style)
  if case_style == "upper" then
    return string.upper(text)
  elseif case_style == "lower" then
    return string.lower(text)
  end
  -- "preserve" or any other value
  return text
end

---Get the appropriate case style for a keyword token
---@param token table The token
---@param config table Formatter configuration
---@return string case_style "upper"|"lower"|"preserve"
local function get_case_style_for_token(token, config)
  -- Functions use function_case (tokenizer marks keyword_category = "function")
  if token.keyword_category == "function" then
    return config.function_case or "upper"
  end

  -- Data types use datatype_case (tokenizer marks keyword_category = "datatype")
  if token.keyword_category == "datatype" then
    return config.datatype_case or "upper"
  end

  -- Regular keywords use keyword_case
  return config.keyword_case or "upper"
end

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Run the casing pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with casing applied
function CasingPass.run(tokens, config)
  config = config or {}

  for _, token in ipairs(tokens) do
    token.original_text = token.text
    token.casing_applied = false

    -- Keywords (SELECT, FROM, etc.)
    if token.type == "keyword" then
      local case_style = get_case_style_for_token(token, config)
      token.text = apply_case(token.text, case_style)
      token.casing_applied = true

    -- GO batch separator (follows keyword_case)
    elseif token.type == "go" then
      local case_style = config.keyword_case or "upper"
      token.text = apply_case(token.text, case_style)
      token.casing_applied = true

    -- Identifiers (table/column names)
    elseif token.type == "identifier" then
      local id_case = config.identifier_case or "preserve"
      if id_case ~= "preserve" then
        token.text = apply_case(token.text, id_case)
        token.casing_applied = true
      end
    end
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function CasingPass.info()
  return {
    name = "casing",
    order = 1,
    description = "Apply casing rules to keywords, functions, and datatypes",
    annotations = {
      "original_text", "casing_applied",
    },
  }
end

return CasingPass
