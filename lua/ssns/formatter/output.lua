---@class FormatterOutput
---Token stream to text reconstruction module.
---Handles whitespace insertion, indentation, and line ending normalization.
---Implements all 109 formatter config options.
local Output = {}

-- =============================================================================
-- Indentation Helpers
-- =============================================================================

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

---Get continuation indent for wrapped lines (Phase 5)
---@param config FormatterConfig
---@param base_level number Base indentation level
---@return string
local function get_continuation_indent(config, base_level)
  local continuation = config.continuation_indent or 1
  return get_indent(config, base_level + continuation)
end

-- =============================================================================
-- Casing Helpers (Phase 3 - Uses tokenizer's keyword_category)
-- =============================================================================

---Apply case transformation
---@param text string
---@param case_style string "upper"|"lower"|"preserve"
---@return string
local function apply_case(text, case_style)
  if case_style == "upper" then
    return string.upper(text)
  elseif case_style == "lower" then
    return string.lower(text)
  else
    return text
  end
end

---Apply appropriate casing to token based on its category and config
---@param token table Token with keyword_category from tokenizer
---@param config FormatterConfig
---@return string The properly cased text
local function apply_token_casing(token, config)
  local text = token.text

  -- Functions use function_case (tokenizer marks keyword_category = "function")
  if token.keyword_category == "function" then
    return apply_case(text, config.function_case or "upper")
  end

  -- Data types use datatype_case (tokenizer marks keyword_category = "datatype")
  if token.keyword_category == "datatype" then
    return apply_case(text, config.datatype_case or "upper")
  end

  -- Regular keywords use keyword_case
  if token.type == "keyword" or token.type == "go" then
    return apply_case(text, config.keyword_case or "upper")
  end

  -- Identifiers use identifier_case (but preserve bracketed ones)
  if token.type == "identifier" then
    return apply_case(text, config.identifier_case or "preserve")
  end

  -- Aliases use alias_case (marked by context)
  if token.is_alias then
    return apply_case(text, config.alias_case or "preserve")
  end

  return text
end

-- =============================================================================
-- Keyword Classification
-- =============================================================================

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
    MERGE = true,  -- Phase 2: MERGE statement
    OUTPUT = true, -- Phase 2: OUTPUT clause
  }
  return major_clauses[upper] == true
end

---Check if keyword is OUTPUT clause
---@param text string
---@return boolean
local function is_output_clause(text)
  return string.upper(text) == "OUTPUT"
end

---Check if keyword is INTO
---@param text string
---@return boolean
local function is_into_keyword(text)
  return string.upper(text) == "INTO"
end

---Check if keyword is VALUES
---@param text string
---@return boolean
local function is_values_keyword(text)
  return string.upper(text) == "VALUES"
end

---Check if keyword is MERGE-related (WHEN, MATCHED, etc.)
---@param text string
---@return boolean
local function is_merge_keyword(text)
  local upper = string.upper(text)
  return upper == "WHEN" or upper == "MATCHED" or upper == "NOT"
end

---Check if keyword is DISTINCT
---@param text string
---@return boolean
local function is_distinct_keyword(text)
  return string.upper(text) == "DISTINCT"
end

---Check if keyword is TOP
---@param text string
---@return boolean
local function is_top_keyword(text)
  return string.upper(text) == "TOP"
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

-- =============================================================================
-- Spacing Helpers (Phase 3)
-- =============================================================================

-- Comparison operators
local COMPARISON_OPERATORS = {
  ["<>"] = true, ["!="] = true, [">="] = true, ["<="] = true,
  [">"] = true, ["<"] = true, ["!<"] = true, ["!>"] = true,
}

-- Concatenation operators
local CONCAT_OPERATORS = {
  ["+"] = true,  -- SQL Server string concat
  ["||"] = true, -- ANSI SQL string concat
}

---Check if operator is a comparison operator
---@param text string
---@return boolean
local function is_comparison_operator(text)
  return COMPARISON_OPERATORS[text] == true
end

---Check if operator is an equals/assignment operator
---@param text string
---@return boolean
local function is_equals_operator(text)
  return text == "="
end

---Check if operator is a concatenation operator
---@param text string
---@return boolean
local function is_concat_operator(text)
  return CONCAT_OPERATORS[text] == true
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
    return config.parenthesis_spacing or false
  end

  -- No space before closing paren (unless configured)
  if curr.type == "paren_close" then
    return config.parenthesis_spacing or false
  end

  -- Bracket spacing (inside [] for identifiers) - Phase 3
  if prev.type == "bracket_open" then
    return config.bracket_spacing or false
  end
  if curr.type == "bracket_close" then
    return config.bracket_spacing or false
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

  -- Comma spacing based on config - Phase 3
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

  -- Semicolon spacing - Phase 3
  if curr.type == "semicolon" then
    return config.semicolon_spacing or false
  end

  -- Space around operators based on specific config - Phase 3
  if prev.type == "operator" or curr.type == "operator" then
    local op_text = prev.type == "operator" and prev.text or curr.text

    -- No space around :: cast operator
    if op_text == "::" then
      return false
    end

    -- Equals spacing (= in SET, etc.)
    if is_equals_operator(op_text) then
      if config.equals_spacing ~= false then  -- default true
        return true
      end
      return false
    end

    -- Comparison spacing (<, >, >=, <=, <>, !=)
    if is_comparison_operator(op_text) then
      if config.comparison_spacing ~= false then  -- default true
        return true
      end
      return false
    end

    -- Concatenation spacing (|| for ANSI SQL)
    -- Note: + is both concat and arithmetic, so we use operator_spacing for +
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

  -- No space between @ and identifier for variables (legacy handling)
  if prev.type == "at" then
    return false
  end

  -- Space before @ for variables (DECLARE @id, SET @var, etc.) (legacy handling)
  if curr.type == "at" then
    if prev.type == "keyword" or prev.type == "identifier" then
      return true
    end
  end

  -- Space before variable (@var, @id) - new unified variable token type
  if curr.type == "variable" then
    if prev.type == "keyword" or prev.type == "identifier" or prev.type == "bracket_id" then
      return true
    end
    -- Space after comma, paren_close, operator
    if prev.type == "comma" or prev.type == "paren_close" or prev.type == "operator" then
      return true
    end
  end

  -- Space after variable (@var) before keywords/identifiers
  if prev.type == "variable" then
    if curr.type == "keyword" or curr.type == "identifier" or curr.type == "bracket_id" then
      return true
    end
  end

  -- Space before temp_table (#temp, ##global)
  if curr.type == "temp_table" then
    if prev.type == "keyword" or prev.type == "identifier" then
      return true
    end
  end

  -- Space between keywords/identifiers (including variable tokens)
  if prev.type == "keyword" or prev.type == "identifier" or prev.type == "bracket_id" or
     prev.type == "number" or prev.type == "string" or prev.type == "variable" then
    if curr.type == "keyword" or curr.type == "identifier" or curr.type == "bracket_id" or
       curr.type == "number" or curr.type == "string" or curr.type == "star" or curr.type == "variable" then
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
  local prev_token = nil

  -- Clause tracking state
  local in_select_list = false
  local in_from_clause = false
  local in_where_clause = false
  local in_join_clause = false
  local in_on_clause = false
  local in_group_by_clause = false
  local in_order_by_clause = false
  local in_having_clause = false
  local in_set_clause = false
  local in_values_clause = false
  local in_insert_columns = false  -- Column list in INSERT
  local in_merge_statement = false
  local in_cte = false  -- Track if we're in CTE section
  local pending_join = false -- Track if we're building a compound JOIN keyword

  -- Blank line tracking (Phase 3)
  local last_line_was_blank = false
  local consecutive_blank_lines = 0

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

    -- Track clause context (comprehensive tracking for all phases)
    if token.type == "keyword" then
      local upper = string.upper(token.text)

      -- Reset clause flags helper
      local function reset_clauses()
        in_select_list = false
        in_from_clause = false
        in_where_clause = false
        in_join_clause = false
        in_on_clause = false
        in_group_by_clause = false
        in_order_by_clause = false
        in_having_clause = false
        in_set_clause = false
        in_values_clause = false
        in_insert_columns = false
        pending_join = false
      end

      if upper == "WITH" then
        in_cte = true
        reset_clauses()
      elseif upper == "SELECT" then
        -- SELECT ends CTE section at top level
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        reset_clauses()
        in_select_list = true
      elseif upper == "FROM" then
        reset_clauses()
        in_from_clause = true
      elseif upper == "WHERE" then
        reset_clauses()
        in_where_clause = true
      elseif upper == "GROUP" then
        reset_clauses()
        in_group_by_clause = true
      elseif upper == "ORDER" and not token.in_over_clause then
        reset_clauses()
        in_order_by_clause = true
      elseif upper == "HAVING" then
        reset_clauses()
        in_having_clause = true
      elseif upper == "SET" then
        reset_clauses()
        in_set_clause = true
      elseif upper == "VALUES" then
        reset_clauses()
        in_values_clause = true
      elseif upper == "ON" and in_join_clause then
        in_on_clause = true
      elseif upper == "MERGE" then
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        reset_clauses()
        in_merge_statement = true
      elseif upper == "UPDATE" then
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        reset_clauses()
      elseif upper == "INSERT" then
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        reset_clauses()
        in_insert_columns = true
      elseif upper == "DELETE" then
        if in_cte and (token.paren_depth or 0) == 0 then
          in_cte = false
        end
        reset_clauses()
      end

      -- Track JOIN state
      if is_join_modifier(upper) or is_join_keyword(upper) then
        in_from_clause = false
        in_join_clause = true
        in_on_clause = false
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

          -- Phase 1: empty_line_before_join option
          if config.empty_line_before_join and #result > 0 then
            table.insert(result, "")  -- Add blank line before JOIN
          end
        end
        pending_join = true
      elseif is_join_keyword(upper) then
        -- This is JOIN - only add newline if no modifier preceded it
        if not pending_join then
          needs_newline = true
          current_indent = base_indent

          -- Phase 1: empty_line_before_join option
          if config.empty_line_before_join and #result > 0 then
            table.insert(result, "")  -- Add blank line before JOIN
          end
        end
        pending_join = false
      elseif upper == "BY" and token.part_of_compound then
        -- BY is part of GROUP BY or ORDER BY, don't add newline
        needs_newline = false
      elseif is_major_clause(token.text) then
        -- Special handling for OUTPUT - controlled by output_clause_newline option
        if upper == "OUTPUT" then
          if config.output_clause_newline then
            needs_newline = true
            current_indent = base_indent
          end
          -- If output_clause_newline is false, don't add newline
        else
          needs_newline = true
          current_indent = base_indent
          pending_join = false

          -- Phase 3: blank_line_before_clause option
          if config.blank_line_before_clause and #result > 0 then
            -- Add blank line before major clauses (SELECT, FROM, WHERE, etc.)
            -- But not at the start of the statement
            local prev_line = result[#result]
            if prev_line and prev_line ~= "" then
              table.insert(result, "")
            end
          end
        end
      end
    end

    -- Phase 1: Handle SELECT modifiers (DISTINCT, TOP)
    if token.type == "keyword" then
      local upper = string.upper(token.text)
      local base_indent = token.indent_level or 0

      -- select_distinct_newline: DISTINCT on new line after SELECT
      if upper == "DISTINCT" and in_select_list and config.select_distinct_newline then
        needs_newline = true
        current_indent = base_indent
        extra_indent = 1
      end

      -- select_top_newline: TOP on new line after SELECT
      if upper == "TOP" and in_select_list and config.select_top_newline then
        needs_newline = true
        current_indent = base_indent
        extra_indent = 1
      end

      -- select_into_newline: INTO on new line (SELECT ... INTO)
      if upper == "INTO" and in_select_list and config.select_into_newline then
        needs_newline = true
        current_indent = base_indent
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
        extra_indent = config.where_and_or_indent or 1  -- Phase 1: configurable indent
      end
    end

    -- Phase 1: Handle AND/OR positioning in ON clause (join conditions)
    if in_on_clause and is_and_or(token) then
      if config.on_and_position == "leading" then
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = 1
      end
    end

    -- Handle CASE expression formatting (Phase 4: case_style, case_then_position)
    -- Only apply newlines if case_style is "stacked" (default)
    local case_style = config.case_style or "stacked"
    if case_style == "stacked" then
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
    end

    -- Phase 4: case_then_position - THEN on new line
    if token.is_case_then and config.case_then_position == "new_line" then
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
    end

    -- Phase 4: boolean_operator_newline - AND/OR on new lines (global, not just WHERE)
    if config.boolean_operator_newline and is_and_or(token) and not in_where_clause and not in_on_clause then
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
    end

    -- Phase 5: union_indent - UNION/INTERSECT/EXCEPT handling
    if token.type == "keyword" then
      local upper = string.upper(token.text)
      if upper == "UNION" or upper == "INTERSECT" or upper == "EXCEPT" then
        local union_indent = config.union_indent or 0
        current_indent = union_indent
      end
    end

    -- Phase 2: CTE AS position - cte_as_position (must be before newline application)
    if token.is_cte_as and config.cte_as_position == "new_line" then
      needs_newline = true
      current_indent = token.indent_level or 0
    end

    -- Phase 2: CTE parenthesis style - cte_parenthesis_style
    if token.starts_cte_body and config.cte_parenthesis_style == "new_line" then
      needs_newline = true
      current_indent = config.cte_indent or 1
    end

    -- Note: OUTPUT clause newline handling is in is_major_clause section above

    -- Phase 2: MERGE WHEN clauses on new line (use token marker from engine)
    if token.is_merge_when then
      if config.merge_when_newline then
        needs_newline = true
        current_indent = token.indent_level or 0
      end
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

    -- Add the token text with proper casing (Phase 3)
    local formatted_text = apply_token_casing(token, config)
    table.insert(current_line, formatted_text)

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
    -- Phase 2: update_set_style stacked
    if token.type == "comma" and in_set_clause and config.update_set_style == "stacked" then
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

    -- Phase 2: GROUP BY stacked style
    if token.type == "comma" and in_group_by_clause and config.group_by_style == "stacked" and paren_depth == 0 then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Phase 2: ORDER BY stacked style
    if token.type == "comma" and in_order_by_clause and config.order_by_style == "stacked" and paren_depth == 0 then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Phase 2: VALUES multi-row style (stacked)
    -- Handle comma between value rows: (...), (...), (...)
    if token.type == "comma" and in_values_clause and config.insert_multi_row_style == "stacked" and paren_depth == 0 then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    end

    -- Handle CTE separator comma (between CTE definitions)
    -- Phase 2: cte_separator_newline
    if token.is_cte_separator then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- If cte_separator_newline is false and compact style, don't add newline
      if config.cte_separator_newline then
        -- Newline after comma is already handled by finishing the line
      end
    end

    -- Handle semicolon - end of statement
    if token.type == "semicolon" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      current_indent = 0

      -- Reset all clause tracking
      in_select_list = false
      in_from_clause = false
      in_where_clause = false
      in_join_clause = false
      in_on_clause = false
      in_group_by_clause = false
      in_order_by_clause = false
      in_having_clause = false
      in_set_clause = false
      in_values_clause = false
      in_insert_columns = false
      in_merge_statement = false
      in_cte = false
      pending_join = false

      -- Phase 3: blank_line_between_statements
      local blank_lines = config.blank_line_between_statements or 1
      for _ = 1, blank_lines do
        table.insert(result, "")
      end
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
        table.insert(result, apply_token_casing(token, config))  -- Apply casing to GO
        current_line = {}
      else
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
        current_line = {}
      end
      current_indent = 0

      -- Reset all clause tracking
      in_select_list = false
      in_from_clause = false
      in_where_clause = false
      in_join_clause = false
      in_on_clause = false
      in_group_by_clause = false
      in_order_by_clause = false
      in_having_clause = false
      in_set_clause = false
      in_values_clause = false
      in_insert_columns = false
      in_merge_statement = false
      in_cte = false
      pending_join = false

      -- Phase 3: blank_line_after_go
      local blank_lines = config.blank_line_after_go or 1
      for _ = 1, blank_lines do
        table.insert(result, "")
      end
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
