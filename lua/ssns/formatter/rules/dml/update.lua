---@class UpdateRule
---@field name string Rule name
---UPDATE statement formatting rules.
---Handles SET clause, assignment alignment.
local Update = {
  name = "update",
}

-- =============================================================================
-- UPDATE Detection
-- =============================================================================

---Check if token is UPDATE keyword
---@param token table
---@return boolean
function Update.is_update(token)
  return token.type == "keyword" and string.upper(token.text) == "UPDATE"
end

---Check if token is SET keyword
---@param token table
---@return boolean
function Update.is_set(token)
  return token.type == "keyword" and string.upper(token.text) == "SET"
end

-- =============================================================================
-- UPDATE Parsing
-- =============================================================================

---Parse SET clause assignments
---@param tokens table[] All tokens
---@param set_idx number Index of SET keyword
---@return table[] assignments Array of {column: string, tokens: table[]}
function Update.parse_set_assignments(tokens, set_idx)
  local assignments = {}
  local idx = set_idx + 1

  local current = {
    column = nil,
    tokens = {},
  }
  local paren_depth = 0
  local case_depth = 0
  local past_equals = false

  while idx <= #tokens do
    local token = tokens[idx]

    -- Track nesting
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    elseif token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "CASE" then
        case_depth = case_depth + 1
      elseif upper == "END" then
        case_depth = math.max(0, case_depth - 1)
      end
    end

    -- End of SET clause
    if paren_depth == 0 and case_depth == 0 then
      if token.type == "keyword" then
        local upper = string.upper(token.text)
        if upper == "FROM" or upper == "WHERE" or upper == "OUTPUT" then
          if #current.tokens > 0 or current.column then
            table.insert(assignments, current)
          end
          break
        end
      end
      if token.type == "semicolon" then
        if #current.tokens > 0 or current.column then
          table.insert(assignments, current)
        end
        break
      end
    end

    -- Comma at depth 0 separates assignments
    if paren_depth == 0 and case_depth == 0 and token.type == "comma" then
      if #current.tokens > 0 or current.column then
        table.insert(assignments, current)
        current = {
          column = nil,
          tokens = {},
        }
        past_equals = false
      end
      idx = idx + 1
      goto continue
    end

    -- Track column name (before =)
    if not past_equals then
      if token.type == "operator" and token.text == "=" then
        past_equals = true
      elseif token.type == "identifier" or token.type == "bracket_id" then
        current.column = token.text
      elseif token.type == "dot" then
        -- Handle schema.column
        current.column = (current.column or "") .. "."
      end
    else
      table.insert(current.tokens, token)
    end

    idx = idx + 1
    ::continue::
  end

  -- Don't forget the last assignment
  if #current.tokens > 0 or current.column then
    table.insert(assignments, current)
  end

  return assignments
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for UPDATE formatting
---@param config FormatterConfig
---@return table update_config
function Update.get_config(config)
  return {
    -- Phase 2 config options
    set_style = config.update_set_style or "stacked",  -- "inline"|"stacked"
    set_align = config.update_set_align or false,      -- Align = in SET
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to UPDATE tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Update.apply(token, context, config)
  local update_config = Update.get_config(config)

  -- Mark UPDATE keyword
  if Update.is_update(token) then
    token.is_update_keyword = true
  end

  -- Mark SET keyword
  if Update.is_set(token) then
    token.is_set_keyword = true
    token.set_style = update_config.set_style
    token.set_align = update_config.set_align
  end

  -- Track UPDATE statement context
  if context.current_clause == "UPDATE" then
    token.in_update_statement = true
  elseif context.current_clause == "SET" then
    token.in_set_clause = true
  end

  return token
end

return Update
