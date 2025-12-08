---@class DeleteRule
---@field name string Rule name
---DELETE statement formatting rules.
---Handles DELETE FROM, TRUNCATE statements.
local Delete = {
  name = "delete",
}

-- =============================================================================
-- DELETE Detection
-- =============================================================================

---Check if token is DELETE keyword
---@param token table
---@return boolean
function Delete.is_delete(token)
  return token.type == "keyword" and string.upper(token.text) == "DELETE"
end

---Check if token is TRUNCATE keyword
---@param token table
---@return boolean
function Delete.is_truncate(token)
  return token.type == "keyword" and string.upper(token.text) == "TRUNCATE"
end

---Check if token is FROM keyword
---@param token table
---@return boolean
function Delete.is_from(token)
  return token.type == "keyword" and string.upper(token.text) == "FROM"
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for DELETE formatting
---@param config FormatterConfig
---@return table delete_config
function Delete.get_config(config)
  return {
    -- Phase 2 config options
    from_keyword = config.delete_from_keyword ~= false, -- default true (always use FROM)
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to DELETE tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Delete.apply(token, context, config)
  local delete_config = Delete.get_config(config)

  -- Mark DELETE keyword
  if Delete.is_delete(token) then
    token.is_delete_keyword = true
    token.delete_from_keyword = delete_config.from_keyword
  end

  -- Mark TRUNCATE keyword
  if Delete.is_truncate(token) then
    token.is_truncate_keyword = true
  end

  -- Track DELETE statement context
  if context.current_clause == "DELETE" then
    token.in_delete_statement = true
  end

  return token
end

return Delete
