---@class AlignmentRule
---@field name string Rule name
---@field apply fun(token: Token, context: FormatterState, config: FormatterConfig): Token
---Alignment rules for SQL formatting (column alignment, AS keyword alignment, etc.).
local Alignment = {
  name = "alignment",
}

---Calculate column width for alias alignment
---@param tokens Token[] List of tokens in the column
---@return number
function Alignment.calculate_column_width(tokens)
  local width = 0
  for _, token in ipairs(tokens) do
    width = width + #token.text
  end
  return width
end

---Find all column expressions in a SELECT list
---@param tokens Token[] All tokens
---@param start_idx number Start index (after SELECT keyword)
---@param end_idx number End index (before FROM keyword)
---@return table[] column_groups Groups of tokens for each column
function Alignment.find_select_columns(tokens, start_idx, end_idx)
  local columns = {}
  local current_column = {}

  for i = start_idx, end_idx do
    local token = tokens[i]
    if token.type == "comma" then
      if #current_column > 0 then
        table.insert(columns, current_column)
        current_column = {}
      end
    else
      table.insert(current_column, token)
    end
  end

  if #current_column > 0 then
    table.insert(columns, current_column)
  end

  return columns
end

---Calculate maximum width before AS keyword for alias alignment
---@param columns table[] Column token groups
---@return number
function Alignment.calculate_alias_alignment_width(columns)
  local max_width = 0

  for _, column in ipairs(columns) do
    local width = 0
    for _, token in ipairs(column) do
      if token.type == "keyword" and string.upper(token.text) == "AS" then
        break
      end
      width = width + #token.text + 1 -- +1 for spacing
    end
    max_width = math.max(max_width, width)
  end

  return max_width
end

---Apply alignment rule to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function Alignment.apply(token, context, config)
  -- Alignment is primarily handled as a post-processing step
  -- in the output generator, not on individual tokens
  return token
end

---Check if token is a window function keyword
---@param token table Token to check
---@return boolean
function Alignment.is_window_function_keyword(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "OVER" or upper == "PARTITION" or upper == "ROWS" or
         upper == "RANGE" or upper == "UNBOUNDED" or upper == "PRECEDING" or
         upper == "FOLLOWING" or upper == "CURRENT"
end

---Check if token is CAST or CONVERT
---@param token table Token to check
---@return boolean
function Alignment.is_cast_convert(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "CAST" or upper == "CONVERT" or upper == "TRY_CAST" or upper == "TRY_CONVERT"
end

---Check if we're inside an OVER clause
---@param tokens table[] Token list
---@param current_idx number Current position
---@return boolean in_over
---@return number|nil over_start_idx
function Alignment.find_over_context(tokens, current_idx)
  -- Look backward for OVER keyword
  local paren_depth = 0
  for i = current_idx, 1, -1 do
    local token = tokens[i]
    if token.type == "paren_close" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_open" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        -- Check if OVER precedes this paren
        local prev_idx = i - 1
        while prev_idx >= 1 and
              (tokens[prev_idx].type == "comment" or tokens[prev_idx].type == "line_comment") do
          prev_idx = prev_idx - 1
        end
        if prev_idx >= 1 and tokens[prev_idx].type == "keyword" and
           string.upper(tokens[prev_idx].text) == "OVER" then
          return true, prev_idx
        end
        return false, nil
      end
    end
  end
  return false, nil
end

---Find function arguments for alignment
---@param tokens table[] Token list
---@param paren_open_idx number Index of opening parenthesis
---@return table[] arguments List of argument token groups
function Alignment.find_function_arguments(tokens, paren_open_idx)
  local arguments = {}
  local current_arg = {}
  local paren_depth = 1
  local i = paren_open_idx + 1

  while i <= #tokens and paren_depth > 0 do
    local token = tokens[i]
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      table.insert(current_arg, token)
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth > 0 then
        table.insert(current_arg, token)
      end
    elseif token.type == "comma" and paren_depth == 1 then
      if #current_arg > 0 then
        table.insert(arguments, current_arg)
        current_arg = {}
      end
    else
      table.insert(current_arg, token)
    end
    i = i + 1
  end

  if #current_arg > 0 then
    table.insert(arguments, current_arg)
  end

  return arguments
end

---Post-process output for alias alignment (if enabled)
---@param lines string[] Output lines
---@param config FormatterConfig
---@return string[]
function Alignment.align_aliases(lines, config)
  if not config.align_aliases then
    return lines
  end

  -- Find the maximum position of AS keyword
  local max_as_pos = 0
  for _, line in ipairs(lines) do
    local as_pos = line:find("%s+AS%s+", 1)
    if as_pos then
      max_as_pos = math.max(max_as_pos, as_pos)
    end
  end

  if max_as_pos == 0 then
    return lines
  end

  -- Align AS keywords
  local aligned = {}
  for _, line in ipairs(lines) do
    local as_start, as_end = line:find("%s+AS%s+")
    if as_start then
      local before = line:sub(1, as_start - 1)
      local after = line:sub(as_end + 1)
      local padding = string.rep(" ", max_as_pos - as_start)
      table.insert(aligned, before .. padding .. " AS " .. after)
    else
      table.insert(aligned, line)
    end
  end

  return aligned
end

return Alignment
