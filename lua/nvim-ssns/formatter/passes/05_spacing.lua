---@class SpacingPass
---Pass 2: Determine spacing between tokens
---This pass annotates tokens with spacing requirements based on context and config.
---
---Annotations added:
---  token.space_before  - true if space should be added before this token
local SpacingPass = {}

-- =============================================================================
-- Pass Implementation
-- =============================================================================

---Determine if space is needed before current token based on previous token
---This mirrors the needs_space_before logic in output.lua but runs as a pre-pass.
---@param prev table|nil Previous token
---@param curr table Current token
---@param config table Formatter configuration
---@return boolean
local function needs_space_before(prev, curr, config)
  -- No previous token = no space needed
  if not prev then
    return false
  end

  -- No space after opening paren (unless configured)
  if prev.type == "paren_open" then
    return config.parenthesis_spacing or false
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    return config.parenthesis_spacing or false
  end

  -- Bracket spacing (inside [] for identifiers)
  if prev.type == "bracket_open" then
    return config.bracket_spacing or false
  end
  if curr.type == "bracket_close" then
    return config.bracket_spacing or false
  end

  -- Space after closing paren before keyword/identifier/operator/star
  if prev.type == "paren_close" then
    if curr.type == "keyword" or curr.type == "identifier" or curr.type == "bracket_id" then
      return true
    end
    -- Space before operator after closing paren
    if curr.type == "operator" or curr.type == "star" then
      return true
    end
  end

  -- Space before opening paren after keyword (IN (, EXISTS (, AS (, etc.)
  -- But NOT for function calls (COUNT(, SUM(, etc.) or table/column names or datatypes
  if curr.type == "paren_open" then
    if prev.type == "keyword" then
      -- No space for SQL functions (COUNT, SUM, AVG, etc.)
      if prev.keyword_category == "function" then
        return false
      end
      -- No space for datatypes (VARCHAR(50), DECIMAL(10,2), etc.)
      if prev.keyword_category == "datatype" then
        return false
      end
      -- Space for keywords like IN, EXISTS, AS
      return true
    end
    -- No space for function calls or table names
    if prev.type == "identifier" or prev.type == "bracket_id" then
      return false
    end
  end

  -- No space after dot (for qualified names)
  if prev.type == "dot" then
    return false
  end

  -- No space before dot
  if curr.type == "dot" then
    return false
  end

  -- Comma spacing based on config
  if curr.type == "comma" then
    local comma_mode = config.comma_spacing or "after"
    if comma_mode == "before" or comma_mode == "both" then
      return true
    end
    return false
  end

  -- Space after comma based on config
  if prev.type == "comma" then
    local comma_mode = config.comma_spacing or "after"
    if comma_mode == "after" or comma_mode == "both" then
      return true
    end
    -- "before" mode and "none" mode both have no space after
    return false
  end

  -- Semicolon spacing
  if curr.type == "semicolon" then
    return config.semicolon_spacing or false
  end

  -- Space around operators based on specific config
  if prev.type == "operator" or curr.type == "operator" then
    local op_text = prev.type == "operator" and prev.text or curr.text

    -- No space around :: cast operator
    if op_text == "::" then
      return false
    end

    -- Equals spacing (= in SET, etc.)
    if op_text == "=" then
      if config.equals_spacing ~= false then  -- default true
        return true
      end
      return false
    end

    -- Comparison spacing (<, >, >=, <=, <>, !=)
    if op_text == "<" or op_text == ">" or op_text == ">=" or
       op_text == "<=" or op_text == "<>" or op_text == "!=" then
      if config.comparison_spacing ~= false then  -- default true
        return true
      end
      return false
    end

    -- Concatenation spacing (|| for ANSI SQL)
    if op_text == "||" then
      if config.concatenation_spacing ~= false then  -- default true
        return true
      end
      return false
    end

    -- General operator spacing for arithmetic (including +, -, *, /)
    if config.operator_spacing ~= false then  -- default true
      return true
    end
    return false
  end

  -- Default: space between most tokens (keywords, identifiers, etc.)
  return true
end

---Run the spacing pass on tokens
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Tokens with spacing annotations
function SpacingPass.run(tokens, config)
  config = config or {}

  local prev_token = nil

  for _, token in ipairs(tokens) do
    -- Calculate space_before based on previous token
    token.space_before = needs_space_before(prev_token, token, config)

    -- Track previous token for next iteration
    prev_token = token
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function SpacingPass.info()
  return {
    name = "spacing",
    order = 2,
    description = "Determine spacing between tokens",
    annotations = {
      "space_before",
    },
  }
end

return SpacingPass
