---@class FormatterOutput
---Token stream to text reconstruction module.
---Handles whitespace insertion, indentation, and line ending normalization.
local Output = {}

---Get the indent string based on configuration
---@param config FormatterConfig
---@param level number Indentation level
---@return string
local function get_indent(config, level)
  if config.indent_style == "tab" then
    return string.rep("\t", level)
  else
    return string.rep(" ", config.indent_size * level)
  end
end

---Check if a keyword is a major clause that should start on a new line
---@param text string
---@return boolean
local function is_major_clause(text)
  local upper = string.upper(text)
  local major_clauses = {
    SELECT = true,
    FROM = true,
    WHERE = true,
    GROUP = true,  -- Start of GROUP BY
    ORDER = true,  -- Start of ORDER BY
    HAVING = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    INSERT = true,
    UPDATE = true,
    DELETE = true,
    SET = true,
    VALUES = true,
    WITH = true,   -- CTE clause
  }
  return major_clauses[upper] == true
end

---Check if keyword is a join modifier (will be followed by JOIN)
---@param text string
---@return boolean
local function is_join_modifier(text)
  local upper = string.upper(text)
  return upper == "INNER" or upper == "LEFT" or upper == "RIGHT" or
         upper == "FULL" or upper == "CROSS" or upper == "NATURAL" or
         upper == "OUTER"
end

---Check if keyword is JOIN
---@param text string
---@return boolean
local function is_join_keyword(text)
  return string.upper(text) == "JOIN"
end

---Check if token is AND or OR
---@param token table
---@return boolean
local function is_and_or(token)
  if token.type ~= "keyword" then
    return false
  end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

---Check if token is ON keyword
---@param token table
---@return boolean
local function is_on_keyword(token)
  return token.type == "keyword" and string.upper(token.text) == "ON"
end

---Determine if space should be added before a token
---@param prev table|nil Previous token
---@param curr table Current token
---@param config FormatterConfig
---@return boolean
local function needs_space_before(prev, curr, config)
  if not prev then
    return false
  end

  -- No space after opening paren (unless configured)
  if prev.type == "paren_open" then
    return config.parenthesis_spacing
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    return config.parenthesis_spacing
  end

  -- Space after closing paren before keyword/identifier/operator/star (e.g., COUNT(*) AS, (a+b) * c)
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
  -- But NOT for function calls (COUNT(, SUM(, etc.) or table/column names
  if curr.type == "paren_open" then
    if prev.type == "keyword" then
      -- No space for SQL functions (COUNT, SUM, AVG, etc.)
      if prev.keyword_category == "function" then
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

  -- No space before comma
  if curr.type == "comma" then
    return false
  end

  -- Space after comma
  if prev.type == "comma" then
    return true
  end

  -- No space before semicolon
  if curr.type == "semicolon" then
    return false
  end

  -- Space around operators (if configured)
  -- Exception: PostgreSQL :: cast operator has no spaces
  if prev.type == "operator" or curr.type == "operator" then
    -- No space around :: cast operator
    if (prev.type == "operator" and prev.text == "::") or
       (curr.type == "operator" and curr.text == "::") then
      return false
    end
    if config.operator_spacing then
      return true
    end
  end

  -- Space around star when used as multiplication operator (between expressions)
  -- e.g., "price * quantity", "(a + b) * c"
  -- But NOT for SELECT * or table.* or function(*) patterns
  if prev.type == "star" or curr.type == "star" then
    -- After star: space if followed by identifier/keyword (price * quantity)
    if prev.type == "star" then
      if curr.type == "identifier" or curr.type == "keyword" or curr.type == "bracket_id" or
         curr.type == "number" or curr.type == "paren_open" then
        return true
      end
    end
    -- Before star: space if preceded by identifier/number/closing paren (quantity *, 5 *, ) *)
    if curr.type == "star" then
      if prev.type == "identifier" or prev.type == "number" or
         prev.type == "bracket_id" or prev.type == "paren_close" then
        return true
      end
    end
  end

  -- No space between @ and identifier for variables
  if prev.type == "at" then
    return false
  end

  -- Space before @ for variables (DECLARE @id, SET @var, etc.)
  if curr.type == "at" then
    if prev.type == "keyword" or prev.type == "identifier" then
      return true
    end
  end

  -- Space before temp_table (#temp, ##global)
  if curr.type == "temp_table" then
    if prev.type == "keyword" or prev.type == "identifier" then
      return true
    end
  end

  -- Space between keywords/identifiers
  if prev.type == "keyword" or prev.type == "identifier" or prev.type == "bracket_id" or
     prev.type == "number" or prev.type == "string" then
    if curr.type == "keyword" or curr.type == "identifier" or curr.type == "bracket_id" or
       curr.type == "number" or curr.type == "string" or curr.type == "star" then
      return true
    end
  end

  -- Space after star if followed by keyword/identifier
  if prev.type == "star" then
    if curr.type == "keyword" or curr.type == "identifier" then
      return true
    end
  end

  return false
end

---Generate formatted output from processed tokens
---@param tokens table[] Processed tokens with formatting metadata
---@param config FormatterConfig Formatter configuration
---@return string
function Output.generate(tokens, config)
  if not tokens or #tokens == 0 then
    return ""
  end

  local result = {}
  local current_line = {}
  local current_indent = 0
  local in_select_list = false
  local in_where_clause = false
  local in_set_clause = false
  local in_values_clause = false
  local in_cte = false  -- Track if we're in CTE section
  local prev_token = nil
  local pending_join = false -- Track if we're building a compound JOIN keyword

  for i, token in ipairs(tokens) do
    local text = token.text
    local needs_newline = false
    local extra_indent = 0

    -- Handle comments specially
    if token.is_comment then
      if token.is_inline_comment then
        -- Inline comment: add space and keep on same line
        if #current_line > 0 then
          table.insert(current_line, " ")
        end
        table.insert(current_line, text)
        -- For line comments, we need to finish the line
        if token.type == "line_comment" then
          local line_text = table.concat(current_line, "")
          if line_text:match("%S") then
            table.insert(result, line_text)
          end
          current_line = {}
        end
      else
        -- Standalone comment: put on its own line with proper indentation
        -- Finish current line first
        if #current_line > 0 then
          local line_text = table.concat(current_line, "")
          if line_text:match("%S") then
            table.insert(result, line_text)
          end
          current_line = {}
        end
        -- Add comment with indentation
        local base_indent = token.indent_level or 0
        local indent = get_indent(config, base_indent)
        -- For block comments that span multiple lines, preserve internal formatting
        if token.type == "comment" and text:find("\n") then
          -- Multi-line block comment - add each line with proper indent
          local comment_lines = {}
          for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(comment_lines, line)
          end
          for j, cline in ipairs(comment_lines) do
            if j == 1 then
              table.insert(result, indent .. cline)
            else
              -- Preserve internal indentation for continuation lines
              table.insert(result, indent .. cline)
            end
          end
        else
          table.insert(result, indent .. text)
        end
      end
      prev_token = token
      goto continue
    end

    -- Track clause context
    if token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "WITH" then
        in_cte = true
        in_select_list = false
        in_where_clause = false
        in_set_clause = false
        in_values_clause = false
        pending_join = false
      elseif upper == "SELECT" then
        -- SELECT ends CTE section at top level
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        in_select_list = true
        in_where_clause = false
        in_set_clause = false
        in_values_clause = false
        pending_join = false
      elseif upper == "FROM" then
        in_select_list = false
        in_where_clause = false
        in_set_clause = false
        in_values_clause = false
      elseif upper == "WHERE" then
        in_select_list = false
        in_where_clause = true
        in_set_clause = false
        in_values_clause = false
        pending_join = false
      elseif upper == "SET" then
        in_select_list = false
        in_where_clause = false
        in_set_clause = true
        in_values_clause = false
        pending_join = false
      elseif upper == "VALUES" then
        in_select_list = false
        in_where_clause = false
        in_set_clause = false
        in_values_clause = true
        pending_join = false
      elseif upper == "UPDATE" or upper == "INSERT" or upper == "DELETE" then
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        in_select_list = false
        in_where_clause = false
        in_set_clause = false
        in_values_clause = false
        pending_join = false
      end
    end

    -- Handle newlines before major clauses
    if config.newline_before_clause and token.type == "keyword" then
      local upper = string.upper(token.text)

      -- Get base indent from token (for subquery support)
      local base_indent = token.indent_level or 0

      -- Skip newlines for keywords inside OVER clause (PARTITION BY, ORDER BY, etc.)
      if token.in_over_clause then
        -- Don't add newline for PARTITION, ORDER, BY inside OVER
        needs_newline = false
      -- Check if this is a join modifier or JOIN keyword
      elseif token.is_join_modifier or is_join_modifier(upper) then
        -- This is a join modifier (INNER, LEFT, OUTER, etc.)
        -- Add newline if this is the START of a new join clause
        if not pending_join then
          needs_newline = true
          current_indent = base_indent
        end
        pending_join = true
      elseif is_join_keyword(upper) then
        -- This is JOIN - only add newline if no modifier preceded it
        if not pending_join then
          needs_newline = true
          current_indent = base_indent
        end
        pending_join = false
      elseif upper == "BY" and token.part_of_compound then
        -- BY is part of GROUP BY or ORDER BY, don't add newline
        needs_newline = false
      elseif is_major_clause(token.text) then
        needs_newline = true
        current_indent = base_indent
        pending_join = false
      end
    end

    -- Handle ON clause positioning
    if is_on_keyword(token) and not config.join_on_same_line then
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
    end

    -- Handle AND/OR positioning in WHERE clause
    if in_where_clause and is_and_or(token) then
      if config.and_or_position == "leading" then
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = 1
      end
    end

    -- Handle CASE expression formatting
    if token.is_case_when then
      -- WHEN starts new line with case indent
      needs_newline = true
      current_indent = token.case_indent or token.indent_level or 0
    elseif token.is_case_else then
      -- ELSE starts new line at same level as WHEN
      needs_newline = true
      current_indent = token.case_indent or token.indent_level or 0
    elseif token.is_case_end then
      -- END starts new line at CASE level (one less than WHEN)
      needs_newline = true
      current_indent = token.case_indent or token.indent_level or 0
    end

    -- Handle comma for column lists (SELECT)
    if token.type == "comma" and in_select_list then
      if config.comma_position == "leading" then
        -- Comma starts new line
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = 1
      end
      -- For trailing, we handle after adding the token
    end

    -- Handle comma for SET clause assignments (UPDATE)
    if token.type == "comma" and in_set_clause then
      -- SET assignments get newlines after commas (trailing comma style)
      -- We handle this after adding the token
    end

    -- Handle CTE separator comma (newline after)
    -- This will be handled after adding the token

    -- Apply newline if needed
    if needs_newline and #current_line > 0 then
      -- Finish current line
      local line_text = table.concat(current_line, "")
      -- Only add if not just whitespace
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}

      -- Start new line with indent
      local indent = get_indent(config, current_indent + extra_indent)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    else
      -- Add space between tokens if needed
      if needs_space_before(prev_token, token, config) then
        table.insert(current_line, " ")
      end
    end

    -- Add the token text
    table.insert(current_line, text)

    -- Handle trailing comma newline in SELECT list
    -- Only at paren_depth 0 (not inside function calls like COUNT(*), COALESCE(a, b), etc.)
    local paren_depth = token.paren_depth or 0
    if token.type == "comma" and in_select_list and config.comma_position == "trailing" and paren_depth == 0 then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent continuation (base indent from subquery + 1 for column list)
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Handle trailing comma newline in SET clause (UPDATE assignments)
    if token.type == "comma" and in_set_clause then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent continuation for SET assignments
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Handle CTE separator comma (between CTE definitions)
    if token.is_cte_separator then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- No indent for next CTE definition (starts at base level)
    end

    -- Handle semicolon - end of statement
    if token.type == "semicolon" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      current_indent = 0
      in_select_list = false
      in_where_clause = false
      in_set_clause = false
      in_values_clause = false
      in_cte = false
      pending_join = false
    end

    -- Handle GO - batch separator
    if token.type == "go" then
      -- Ensure GO is on its own line
      if #current_line > 1 then
        -- There's content before GO
        local go_text = table.remove(current_line)
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
        table.insert(result, go_text)
        current_line = {}
      else
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
        current_line = {}
      end
      current_indent = 0
      in_select_list = false
      in_where_clause = false
      in_set_clause = false
      in_values_clause = false
      in_cte = false
      pending_join = false
    end

    -- Reset pending_join if we hit something other than OUTER or JOIN
    if token.type == "keyword" then
      local upper = string.upper(token.text)
      if pending_join and upper ~= "OUTER" and upper ~= "JOIN" and not is_join_modifier(upper) then
        pending_join = false
      end
    end

    prev_token = token
    ::continue::
  end

  -- Don't forget remaining tokens
  if #current_line > 0 then
    local line_text = table.concat(current_line, "")
    if line_text:match("%S") then
      table.insert(result, line_text)
    end
  end

  return table.concat(result, "\n")
end

return Output
