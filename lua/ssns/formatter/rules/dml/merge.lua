---@class MergeRule
---@field name string Rule name
---MERGE statement formatting rules.
---Handles USING, WHEN MATCHED, WHEN NOT MATCHED clauses.
local Merge = {
  name = "merge",
}

-- =============================================================================
-- MERGE Detection
-- =============================================================================

---Check if token is MERGE keyword
---@param token table
---@return boolean
function Merge.is_merge(token)
  return token.type == "keyword" and string.upper(token.text) == "MERGE"
end

---Check if token is USING keyword
---@param token table
---@return boolean
function Merge.is_using(token)
  return token.type == "keyword" and string.upper(token.text) == "USING"
end

---Check if token is MATCHED keyword
---@param token table
---@return boolean
function Merge.is_matched(token)
  return token.type == "keyword" and string.upper(token.text) == "MATCHED"
end

---Check if token is WHEN keyword
---@param token table
---@return boolean
function Merge.is_when(token)
  return token.type == "keyword" and string.upper(token.text) == "WHEN"
end

---Check if token is THEN keyword
---@param token table
---@return boolean
function Merge.is_then(token)
  return token.type == "keyword" and string.upper(token.text) == "THEN"
end

---Check if token is TARGET keyword
---@param token table
---@return boolean
function Merge.is_target(token)
  return token.type == "keyword" and string.upper(token.text) == "TARGET"
end

---Check if token is SOURCE keyword
---@param token table
---@return boolean
function Merge.is_source(token)
  return token.type == "keyword" and string.upper(token.text) == "SOURCE"
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for MERGE formatting
---@param config FormatterConfig
---@return table merge_config
function Merge.get_config(config)
  return {
    -- Phase 2 config options
    merge_style = config.merge_style or "expanded",        -- "compact"|"expanded"
    when_newline = config.merge_when_newline ~= false,     -- default true
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to MERGE tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Merge.apply(token, context, config)
  local merge_config = Merge.get_config(config)

  -- Mark MERGE keyword
  if Merge.is_merge(token) then
    token.is_merge_keyword = true
    token.merge_style = merge_config.merge_style
  end

  -- Mark USING keyword
  if Merge.is_using(token) then
    token.is_using_keyword = true
  end

  -- Mark WHEN keyword
  if Merge.is_when(token) then
    token.is_merge_when = true
    token.merge_when_newline = merge_config.when_newline
  end

  -- Mark MATCHED keyword
  if Merge.is_matched(token) then
    token.is_matched_keyword = true
  end

  -- Mark THEN keyword in MERGE context
  if Merge.is_then(token) and context.in_merge then
    token.is_merge_then = true
  end

  -- Track MERGE statement context
  if context.current_clause == "MERGE" then
    token.in_merge_statement = true
  end

  return token
end

return Merge
