---@class CteRule
---@field name string Rule name
---CTE (Common Table Expression) formatting rules.
---Handles WITH clause, AS positioning, CTE column lists.
local Cte = {
  name = "cte",
}

-- =============================================================================
-- CTE Detection
-- =============================================================================

---Check if token is WITH keyword
---@param token table
---@return boolean
function Cte.is_with(token)
  return token.type == "keyword" and string.upper(token.text) == "WITH"
end

---Check if token is RECURSIVE keyword
---@param token table
---@return boolean
function Cte.is_recursive(token)
  return token.type == "keyword" and string.upper(token.text) == "RECURSIVE"
end

---Check if token is AS keyword
---@param token table
---@return boolean
function Cte.is_as(token)
  return token.type == "keyword" and string.upper(token.text) == "AS"
end

---Check if token starts the main query after CTEs
---@param token table
---@return boolean
function Cte.is_main_query_start(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "SELECT" or upper == "INSERT" or upper == "UPDATE" or upper == "DELETE" or upper == "MERGE"
end

-- =============================================================================
-- CTE Parsing
-- =============================================================================

---Parse CTE definitions from a WITH clause
---@param tokens table[] All tokens
---@param with_idx number Index of WITH keyword
---@return table[] ctes Array of {name: string, columns: string[]?, body_start: number, body_end: number}
function Cte.parse_ctes(tokens, with_idx)
  local ctes = {}
  local idx = with_idx + 1

  -- Skip RECURSIVE if present
  if idx <= #tokens and Cte.is_recursive(tokens[idx]) then
    idx = idx + 1
  end

  while idx <= #tokens do
    local cte = {
      name = nil,
      columns = nil,
      body_start = nil,
      body_end = nil,
    }

    -- CTE name
    if tokens[idx].type == "identifier" or tokens[idx].type == "bracket_id" then
      cte.name = tokens[idx].text
      idx = idx + 1
    else
      break
    end

    -- Optional column list
    if idx <= #tokens and tokens[idx].type == "paren_open" then
      cte.columns = {}
      local paren_depth = 1
      idx = idx + 1
      local current_col = ""

      while idx <= #tokens and paren_depth > 0 do
        local token = tokens[idx]
        if token.type == "paren_open" then
          paren_depth = paren_depth + 1
        elseif token.type == "paren_close" then
          paren_depth = paren_depth - 1
          if paren_depth == 0 then
            if current_col ~= "" then
              table.insert(cte.columns, current_col)
            end
            idx = idx + 1
            break
          end
        elseif token.type == "comma" and paren_depth == 1 then
          if current_col ~= "" then
            table.insert(cte.columns, current_col)
            current_col = ""
          end
        elseif token.type == "identifier" or token.type == "bracket_id" then
          current_col = token.text
        end
        idx = idx + 1
      end
    end

    -- AS keyword
    if idx <= #tokens and Cte.is_as(tokens[idx]) then
      idx = idx + 1
    else
      break
    end

    -- CTE body (parenthesized SELECT)
    if idx <= #tokens and tokens[idx].type == "paren_open" then
      cte.body_start = idx
      local paren_depth = 1
      idx = idx + 1

      while idx <= #tokens and paren_depth > 0 do
        if tokens[idx].type == "paren_open" then
          paren_depth = paren_depth + 1
        elseif tokens[idx].type == "paren_close" then
          paren_depth = paren_depth - 1
          if paren_depth == 0 then
            cte.body_end = idx
          end
        end
        idx = idx + 1
      end
    end

    table.insert(ctes, cte)

    -- Check for comma (more CTEs) or end
    if idx <= #tokens and tokens[idx].type == "comma" then
      idx = idx + 1
    elseif idx <= #tokens and Cte.is_main_query_start(tokens[idx]) then
      break
    else
      break
    end
  end

  return ctes
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for CTE formatting
---@param config FormatterConfig
---@return table cte_config
function Cte.get_config(config)
  return {
    -- Phase 2 config options (placeholders for future implementation)
    cte_style = config.cte_style or "expanded",            -- "compact"|"expanded"
    cte_as_position = config.cte_as_position or "same_line", -- "same_line"|"new_line"
    cte_parenthesis_style = config.cte_parenthesis_style or "new_line", -- "same_line"|"new_line"
    cte_columns_style = config.cte_columns_style or "inline", -- "inline"|"stacked"
    cte_separator_newline = config.cte_separator_newline or false,
  }
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to CTE tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Cte.apply(token, context, config)
  local cte_config = Cte.get_config(config)

  -- Mark WITH keyword
  if Cte.is_with(token) then
    token.is_cte_start = true
    token.cte_style = cte_config.cte_style
  end

  -- Mark RECURSIVE keyword
  if Cte.is_recursive(token) then
    token.is_cte_recursive = true
  end

  -- Mark AS keyword in CTE context
  if Cte.is_as(token) and context.in_cte then
    token.is_cte_as = true
    token.cte_as_position = cte_config.cte_as_position
  end

  -- Mark CTE name
  if context.cte_name_expected and (token.type == "identifier" or token.type == "bracket_id") then
    token.is_cte_name = true
  end

  -- Mark CTE body parentheses
  if token.type == "paren_open" and context.cte_body_start then
    token.starts_cte_body = true
    token.cte_parenthesis_style = cte_config.cte_parenthesis_style
  end

  -- Mark CTE separator comma
  if token.type == "comma" and context.in_cte and context.paren_depth == 0 then
    token.is_cte_separator = true
    token.cte_separator_newline = cte_config.cte_separator_newline
  end

  return token
end

return Cte
