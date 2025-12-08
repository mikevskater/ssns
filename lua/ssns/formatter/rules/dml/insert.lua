---@class InsertRule
---@field name string Rule name
---INSERT statement formatting rules.
---Handles column lists, VALUES formatting, OUTPUT clause.
local Insert = {
  name = "insert",
}

-- =============================================================================
-- INSERT Detection
-- =============================================================================

---Check if token is INSERT keyword
---@param token table
---@return boolean
function Insert.is_insert(token)
  return token.type == "keyword" and string.upper(token.text) == "INSERT"
end

---Check if token is INTO keyword
---@param token table
---@return boolean
function Insert.is_into(token)
  return token.type == "keyword" and string.upper(token.text) == "INTO"
end

---Check if token is VALUES keyword
---@param token table
---@return boolean
function Insert.is_values(token)
  return token.type == "keyword" and string.upper(token.text) == "VALUES"
end

---Check if token is DEFAULT keyword
---@param token table
---@return boolean
function Insert.is_default(token)
  return token.type == "keyword" and string.upper(token.text) == "DEFAULT"
end

---Check if token is OUTPUT keyword
---@param token table
---@return boolean
function Insert.is_output(token)
  return token.type == "keyword" and string.upper(token.text) == "OUTPUT"
end

-- =============================================================================
-- INSERT Parsing
-- =============================================================================

---Parse INSERT column list
---@param tokens table[] All tokens
---@param insert_idx number Index of INSERT keyword
---@return table|nil column_list {start_idx: number, end_idx: number, columns: string[]}
function Insert.parse_columns(tokens, insert_idx)
  local idx = insert_idx + 1

  -- Skip INTO
  if idx <= #tokens and Insert.is_into(tokens[idx]) then
    idx = idx + 1
  end

  -- Skip table name (may be schema.table)
  while idx <= #tokens do
    local token = tokens[idx]
    if token.type == "identifier" or token.type == "bracket_id" or token.type == "dot" then
      idx = idx + 1
    else
      break
    end
  end

  -- Look for opening paren (column list)
  if idx > #tokens or tokens[idx].type ~= "paren_open" then
    return nil -- No column list
  end

  local start_idx = idx
  local paren_depth = 1
  idx = idx + 1

  local columns = {}
  local current_col = ""

  while idx <= #tokens and paren_depth > 0 do
    local token = tokens[idx]

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        if current_col ~= "" then
          table.insert(columns, current_col)
        end
        return {
          start_idx = start_idx,
          end_idx = idx,
          columns = columns,
        }
      end
    elseif token.type == "comma" and paren_depth == 1 then
      if current_col ~= "" then
        table.insert(columns, current_col)
        current_col = ""
      end
    else
      current_col = current_col .. token.text
    end

    idx = idx + 1
  end

  return nil
end

---Parse VALUES clause
---@param tokens table[] All tokens
---@param values_idx number Index of VALUES keyword
---@return table[] value_rows Array of {start_idx: number, end_idx: number, values: table[]}
function Insert.parse_values(tokens, values_idx)
  local rows = {}
  local idx = values_idx + 1

  while idx <= #tokens do
    -- Look for opening paren (value row)
    while idx <= #tokens and tokens[idx].type ~= "paren_open" do
      if tokens[idx].type == "semicolon" then
        return rows
      end
      idx = idx + 1
    end

    if idx > #tokens then
      break
    end

    local row = {
      start_idx = idx,
      end_idx = nil,
      values = {},
    }

    local paren_depth = 1
    idx = idx + 1
    local current_value = {}

    while idx <= #tokens and paren_depth > 0 do
      local token = tokens[idx]

      if token.type == "paren_open" then
        paren_depth = paren_depth + 1
        table.insert(current_value, token)
      elseif token.type == "paren_close" then
        paren_depth = paren_depth - 1
        if paren_depth == 0 then
          if #current_value > 0 then
            table.insert(row.values, current_value)
          end
          row.end_idx = idx
        else
          table.insert(current_value, token)
        end
      elseif token.type == "comma" and paren_depth == 1 then
        if #current_value > 0 then
          table.insert(row.values, current_value)
          current_value = {}
        end
      else
        table.insert(current_value, token)
      end

      idx = idx + 1
    end

    if row.end_idx then
      table.insert(rows, row)
    end

    -- Check for comma (more rows) or end
    if idx <= #tokens and tokens[idx].type == "comma" then
      idx = idx + 1
    else
      break
    end
  end

  return rows
end

-- =============================================================================
-- Configuration
-- =============================================================================

---Get configuration for INSERT formatting
---@param config FormatterConfig
---@return table insert_config
function Insert.get_config(config)
  return {
    -- Phase 2 config options
    columns_style = config.insert_columns_style or "inline",  -- "inline"|"stacked"
    values_style = config.insert_values_style or "inline",    -- "inline"|"stacked"
    into_keyword = config.insert_into_keyword ~= false,       -- default true
    multi_row_style = config.insert_multi_row_style or "stacked", -- "inline"|"stacked"
    max_inline_values = 3, -- Go multi-line if more values per row
  }
end

---Check if VALUES clause should be multi-line
---@param value_rows table[] Parsed value rows
---@param max_inline number Maximum values per row before going multi-line
---@return boolean
function Insert.should_multiline_values(value_rows, max_inline)
  max_inline = max_inline or 3

  -- Multiple rows always multi-line
  if #value_rows > 1 then
    return true
  end

  -- Check single row
  if #value_rows == 1 and #value_rows[1].values > max_inline then
    return true
  end

  return false
end

-- =============================================================================
-- Application
-- =============================================================================

---Apply formatting to INSERT tokens
---@param token table Current token
---@param context table Formatting context
---@param config FormatterConfig
---@return table token Modified token with formatting hints
function Insert.apply(token, context, config)
  local insert_config = Insert.get_config(config)

  -- Mark INSERT keyword
  if Insert.is_insert(token) then
    token.is_insert_keyword = true
  end

  -- Mark INTO keyword
  if Insert.is_into(token) then
    token.is_into_keyword = true
    token.insert_into_keyword = insert_config.into_keyword
  end

  -- Mark VALUES keyword
  if Insert.is_values(token) then
    token.is_values_keyword = true
    token.values_style = insert_config.values_style
    token.multi_row_style = insert_config.multi_row_style
  end

  -- Mark OUTPUT keyword
  if Insert.is_output(token) then
    token.is_output_keyword = true
  end

  -- Track INSERT statement context
  if context.current_clause == "INSERT" then
    token.in_insert_statement = true
    token.columns_style = insert_config.columns_style
  elseif context.current_clause == "VALUES" then
    token.in_values_clause = true
  end

  return token
end

return Insert
