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

---Check if keyword is APPLY (for CROSS APPLY, OUTER APPLY)
---@param text string
---@return boolean
local function is_apply_keyword(text)
  return string.upper(text) == "APPLY"
end

---Check if keyword is CROSS or OUTER (potential APPLY modifier)
---@param text string
---@return boolean
local function is_apply_modifier(text)
  local upper = string.upper(text)
  return upper == "CROSS" or upper == "OUTER"
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

---Flush SET alignment buffer to result
---@param buffer table[] Array of assignment entries {column_name, tokens_text, indent}
---@param result table[] Result lines array
---@param max_width number Maximum column name width
---@param config FormatterConfig Formatter configuration
local function flush_set_align_buffer(buffer, result, max_width, config)
  for idx, entry in ipairs(buffer) do
    local col_name = entry.column_name
    local value_text = entry.value_text
    local indent = entry.indent or ""

    -- Calculate padding needed to align equals sign
    local padding = string.rep(" ", max_width - #col_name)

    -- Build the line: indent + column + padding + space + = + space + value + comma
    local line = indent .. col_name .. padding .. " = " .. value_text
    if idx < #buffer then
      line = line .. ","
    end
    table.insert(result, line)
  end
end

---Parse a FROM/JOIN line to extract components
---@param line string The line to parse
---@return string|nil indent Leading whitespace
---@return string|nil keyword FROM or JOIN keyword with trailing space
---@return string|nil table_name Table name (possibly schema-qualified)
---@return string|nil as_keyword AS keyword if present (with space)
---@return string|nil alias Table alias
---@return string|nil rest Remainder of line (e.g., ON clause)
local function parse_from_join_line(line)
  -- Try JOIN patterns first (INNER JOIN, LEFT JOIN, RIGHT JOIN, CROSS JOIN, JOIN)
  -- Pattern with AS keyword
  local indent, keyword, table_name, as_kw, alias, rest = line:match("^(%s*)([A-Z]*%s*JOIN%s+)([%w_.]+)%s+([Aa][Ss])%s+([%w_]+)(.*)$")
  if indent then
    return indent, keyword, table_name, as_kw .. " ", alias, rest
  end

  -- JOIN pattern without AS keyword
  indent, keyword, table_name, alias, rest = line:match("^(%s*)([A-Z]*%s*JOIN%s+)([%w_.]+)%s+([%w_]+)(.*)$")
  if indent then
    return indent, keyword, table_name, nil, alias, rest
  end

  -- Try FROM patterns
  -- Pattern with AS keyword
  indent, keyword, table_name, as_kw, alias, rest = line:match("^(%s*)(FROM%s+)([%w_.]+)%s+([Aa][Ss])%s+([%w_]+)(.*)$")
  if indent then
    return indent, keyword, table_name, as_kw .. " ", alias, rest
  end

  -- FROM pattern without AS keyword
  indent, keyword, table_name, alias, rest = line:match("^(%s*)(FROM%s+)([%w_.]+)%s+([%w_]+)(.*)$")
  if indent then
    return indent, keyword, table_name, nil, alias, rest
  end

  return nil
end

---Post-process result lines to align FROM/JOIN table aliases
---@param result table[] Result lines array
---@param config FormatterConfig Formatter configuration
---@return table[] Modified result lines
local function align_from_aliases(result, config)
  if not config.from_alias_align then
    return result
  end

  -- First pass: find all FROM/JOIN lines and max table name width
  local max_table_width = 0
  local from_join_info = {} -- Store parsed info for each matching line

  for i, line in ipairs(result) do
    local indent, keyword, table_name, as_kw, alias, rest = parse_from_join_line(line)
    if table_name and alias then
      from_join_info[i] = {
        indent = indent,
        keyword = keyword,
        table_name = table_name,
        as_keyword = as_kw,
        alias = alias,
        rest = rest or ""
      }
      if #table_name > max_table_width then
        max_table_width = #table_name
      end
    end
  end

  -- Second pass: apply alignment padding
  for i, info in pairs(from_join_info) do
    local padding = string.rep(" ", max_table_width - #info.table_name + 1) -- +1 for minimum space
    local new_line = info.indent .. info.keyword .. info.table_name .. padding
    if info.as_keyword then
      new_line = new_line .. info.as_keyword .. info.alias
    else
      new_line = new_line .. info.alias
    end
    new_line = new_line .. info.rest
    result[i] = new_line
  end

  return result
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
  local in_insert_columns_paren = false  -- Inside INSERT (...) column list parentheses
  local insert_columns_paren_depth = 0  -- Track parenthesis depth for INSERT column list
  local pending_insert_columns_stacked_indent_newline = false  -- For stacked_indent: newline after INSERT (
  local in_values_paren = false  -- Inside VALUES (...) parentheses
  local values_paren_depth = 0  -- Track parenthesis depth for VALUES clause
  local pending_values_stacked_indent_newline = false  -- For stacked_indent: newline after VALUES (
  local in_merge_statement = false
  local in_cte = false  -- Track if we're in CTE section
  local in_cte_columns = false  -- Track if we're in CTE column list (cte_name (...) AS)
  local in_cte_columns_paren = false  -- Inside CTE column list parentheses
  local cte_columns_paren_depth = 0  -- Track parenthesis depth for CTE column list
  local pending_cte_columns_stacked_indent_newline = false  -- For stacked_indent: newline after CTE name (
  local in_create_table = false  -- Track if we're in CREATE TABLE column definitions
  local create_table_paren_depth = 0  -- Track parenthesis depth for CREATE TABLE
  local pending_create = false  -- Track if we saw CREATE (waiting for TABLE/VIEW/etc)
  local in_in_clause = false  -- Track if we're in IN (...) list
  local in_clause_paren_depth = 0  -- Track parenthesis depth for IN clause
  local pending_in = false  -- Track if we saw IN keyword (waiting for open paren)
  local pending_in_stacked_indent_newline = false  -- For stacked_indent: newline after IN (
  local pending_join = false -- Track if we're building a compound JOIN keyword
  local join_modifiers = {} -- Track accumulated JOIN modifiers (LEFT, RIGHT, FULL, INNER, OUTER)
  local pending_apply = false -- Track if we're building CROSS APPLY or OUTER APPLY
  local pending_stacked_indent_newline = false -- For stacked_indent: newline after SELECT
  local pending_where_stacked_indent_newline = false -- For where stacked_indent: newline after WHERE
  local pending_from_stacked_indent_newline = false -- For from stacked_indent: newline after FROM
  local pending_on_stacked_indent_newline = false -- For on stacked_indent: newline after ON
  local line_just_started = false -- Track if we just started a new line with indent
  local skip_token = false -- Flag to skip outputting current token (for join_keyword_style)

  -- Phase 2: update_set_align - buffering for SET clause alignment
  local set_align_buffer = {} -- Buffer for SET assignments: {column_name, assignment_tokens}
  local set_align_current = nil -- Current assignment being built: {column = "", tokens = {}}
  local set_align_active = false -- Whether we're actively buffering SET assignments
  local set_align_max_col_width = 0 -- Maximum column name width in SET clause
  local in_update_statement = false -- Track if we're in UPDATE statement

  -- Phase 4: function_arg_style - track function call state
  local pending_function_call = false -- Track if we just saw a function keyword
  local function_call_stack = {} -- Stack of {paren_depth, arg_count} for nested function calls
  local function_paren_depth = 0 -- Current parenthesis depth within function calls
  local pending_function_stacked_indent_newline = false -- For stacked_indent: newline after function (

  -- Blank line tracking (Phase 3)
  local last_line_was_blank = false
  local consecutive_blank_lines = 0

  -- Comprehensive state reset function for statement/batch boundaries
  -- This resets all clause tracking and pending flags
  local function reset_all_state()
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
    in_insert_columns_paren = false
    insert_columns_paren_depth = 0
    pending_insert_columns_stacked_indent_newline = false
    in_values_paren = false
    values_paren_depth = 0
    pending_values_stacked_indent_newline = false
    in_merge_statement = false
    in_cte = false
    in_cte_columns = false
    in_cte_columns_paren = false
    cte_columns_paren_depth = 0
    pending_cte_columns_stacked_indent_newline = false
    in_create_table = false
    create_table_paren_depth = 0
    pending_create = false
    in_in_clause = false
    in_clause_paren_depth = 0
    pending_in = false
    pending_in_stacked_indent_newline = false
    pending_join = false
    pending_stacked_indent_newline = false
    pending_where_stacked_indent_newline = false
    pending_from_stacked_indent_newline = false
    pending_on_stacked_indent_newline = false
    pending_function_call = false
    pending_function_stacked_indent_newline = false
    function_call_stack = {}
    function_paren_depth = 0
  end

  for i, token in ipairs(tokens) do
    local text = token.text
    local needs_newline = false
    local extra_indent = 0
    local add_empty_line_after_flush = false  -- Flag to add empty line after flushing current line
    local skip_space_before = line_just_started  -- Skip space if we just added indent
    line_just_started = false  -- Reset the flag

    -- Phase 1: Handle pending stacked_indent newline (first column after SELECT)
    -- Skip SELECT modifiers (DISTINCT, TOP, ALL) - only trigger newline for actual columns
    if pending_stacked_indent_newline and not token.is_comment then
      local upper = token.type == "keyword" and string.upper(token.text) or ""
      local is_select_modifier = upper == "DISTINCT" or upper == "TOP" or upper == "ALL"
      -- Also skip numbers after TOP (e.g., TOP 10)
      local is_top_number = token.type == "number"
      -- Skip PERCENT and WITH TIES after TOP
      local is_top_modifier = upper == "PERCENT" or upper == "WITH" or upper == "TIES"

      if not is_select_modifier and not is_top_number and not is_top_modifier then
        -- This is the first actual column - add newline
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = 1
        pending_stacked_indent_newline = false
      end
      -- If it's a modifier, keep the flag active for next token
    end

    -- Phase 1: Handle pending where_condition_style stacked_indent newline (first condition after WHERE)
    if pending_where_stacked_indent_newline and not token.is_comment then
      -- First condition after WHERE - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_where_stacked_indent_newline = false
    end

    -- Phase 1: Handle pending from_table_style stacked_indent newline (first table after FROM)
    if pending_from_stacked_indent_newline and not token.is_comment then
      -- First table after FROM - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_from_stacked_indent_newline = false
    end

    -- Phase 1: Handle pending on_condition_style stacked_indent newline (first condition after ON)
    if pending_on_stacked_indent_newline and not token.is_comment then
      -- First condition after ON - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_on_stacked_indent_newline = false
    end

    -- Phase 4: Handle pending in_list_style stacked_indent newline (first value after IN ()
    if pending_in_stacked_indent_newline and not token.is_comment and token.type ~= "paren_open" then
      -- First value after IN ( - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_in_stacked_indent_newline = false
    end

    -- Phase 2: Handle pending insert_columns_style stacked_indent newline (first column after INSERT (...))
    if pending_insert_columns_stacked_indent_newline and not token.is_comment and token.type ~= "paren_close" then
      -- First column after INSERT ( - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_insert_columns_stacked_indent_newline = false
    end

    -- Phase 2: Handle pending insert_values_style stacked_indent newline (first value after VALUES (...))
    if pending_values_stacked_indent_newline and not token.is_comment and token.type ~= "paren_close" then
      -- First value after VALUES ( - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_values_stacked_indent_newline = false
    end

    -- Phase 2: Handle pending cte_columns_style stacked_indent newline (first column after CTE name (...))
    if pending_cte_columns_stacked_indent_newline and not token.is_comment and token.type ~= "paren_close" then
      -- First column after CTE name ( - add newline
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
      pending_cte_columns_stacked_indent_newline = false
    end

    -- Phase 4: Handle pending function_arg_style stacked_indent newline (first arg after function ()
    if pending_function_stacked_indent_newline and not token.is_comment and token.type ~= "paren_close" then
      -- First arg after function ( - add newline
      needs_newline = true
      if #function_call_stack > 0 then
        current_indent = function_call_stack[#function_call_stack].base_indent or 0
      end
      extra_indent = 1
      pending_function_stacked_indent_newline = false
    end

    -- Phase 4: Handle subquery_paren_style for subquery opening parens
    if token.starts_subquery and config.subquery_paren_style == "new_line" then
      -- Put subquery opening paren on new line
      needs_newline = true
      current_indent = token.indent_level or 0
    end

    -- Handle comments specially
    if token.is_comment then
      local comment_position = config.comment_position or "preserve"

      -- Determine if this comment should be on its own line (above)
      local force_above = (comment_position == "above")

      if token.is_inline_comment and not force_above then
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
        -- Standalone comment OR force_above: put on its own line with proper indentation
        -- Finish current line first
        if #current_line > 0 then
          local line_text = table.concat(current_line, "")
          if line_text:match("%S") then
            table.insert(result, line_text)
          end
          current_line = {}
        end

        -- Phase 3: blank_line_before_comment - add blank line before standalone comments
        if config.blank_line_before_comment then
          -- Only add blank line if there's content before this comment
          -- and the previous line isn't already blank
          if #result > 0 and result[#result]:match("%S") then
            table.insert(result, "")
          end
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
        in_insert_columns_paren = false
        insert_columns_paren_depth = 0
        pending_insert_columns_stacked_indent_newline = false
        pending_join = false
        pending_where_stacked_indent_newline = false
        pending_from_stacked_indent_newline = false
        pending_on_stacked_indent_newline = false
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
        -- Flush SET alignment buffer if active (UPDATE ... SET ... FROM)
        if set_align_active then
          -- Capture the last assignment (the current_line before FROM)
          local line_text = table.concat(current_line, "")
          if line_text:match("%S") then
            -- Parse the line to extract column name and value
            local indent_part, prefix, col_part, value_part
            -- First try with SET prefix (single assignment case)
            indent_part, prefix, col_part, value_part = line_text:match("^(%s*)(SET%s+)([^=]+)%s*=%s*(.+)$")
            if not indent_part then
              -- Try without SET
              indent_part, col_part, value_part = line_text:match("^(%s*)([^=]+)%s*=%s*(.+)$")
              prefix = ""
            end
            if col_part then
              col_part = col_part:match("^%s*(.-)%s*$") -- trim
              if #col_part > set_align_max_col_width then
                set_align_max_col_width = #col_part
              end
              table.insert(set_align_buffer, {
                column_name = col_part,
                value_text = value_part or "",
                indent = (indent_part or "") .. (prefix or "")
              })
            end
          end
          if #set_align_buffer > 0 then
            flush_set_align_buffer(set_align_buffer, result, set_align_max_col_width, config)
          end
          current_line = {}  -- Clear current line since we handled it
          skip_space_before = true  -- Skip leading space for FROM
          set_align_active = false
          set_align_buffer = {}
          set_align_current = nil
          in_update_statement = false
        end
        reset_clauses()
        in_from_clause = true
        -- Phase 1: from_table_style stacked_indent - set flag to add newline before first table
        local from_table_style = config.from_table_style or "inline"
        if from_table_style == "stacked_indent" then
          pending_from_stacked_indent_newline = true
        end
      elseif upper == "WHERE" then
        -- Flush SET alignment buffer if active (UPDATE ... SET ... WHERE)
        if set_align_active then
          -- Capture the last assignment (the current_line before WHERE)
          local line_text = table.concat(current_line, "")
          if line_text:match("%S") then
            -- Parse the line to extract column name and value
            local indent_part, prefix, col_part, value_part
            -- First try with SET prefix (single assignment case)
            indent_part, prefix, col_part, value_part = line_text:match("^(%s*)(SET%s+)([^=]+)%s*=%s*(.+)$")
            if not indent_part then
              -- Try without SET
              indent_part, col_part, value_part = line_text:match("^(%s*)([^=]+)%s*=%s*(.+)$")
              prefix = ""
            end
            if col_part then
              col_part = col_part:match("^%s*(.-)%s*$") -- trim
              if #col_part > set_align_max_col_width then
                set_align_max_col_width = #col_part
              end
              table.insert(set_align_buffer, {
                column_name = col_part,
                value_text = value_part or "",
                indent = (indent_part or "") .. (prefix or "")
              })
            end
          end
          if #set_align_buffer > 0 then
            flush_set_align_buffer(set_align_buffer, result, set_align_max_col_width, config)
          end
          current_line = {}  -- Clear current line since we handled it
          skip_space_before = true  -- Skip leading space for WHERE
          set_align_active = false
          set_align_buffer = {}
          set_align_current = nil
          in_update_statement = false
        end
        reset_clauses()
        in_where_clause = true
        -- Phase 1: where_condition_style stacked_indent - set flag for first condition
        local where_style = config.where_condition_style or "stacked"
        if where_style == "stacked_indent" then
          pending_where_stacked_indent_newline = true
        end
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
        -- Activate SET alignment buffering if enabled and in UPDATE statement with stacked style
        if in_update_statement and config.update_set_align and config.update_set_style == "stacked" then
          set_align_active = true
          set_align_buffer = {}
          set_align_current = { column_name = "", value_tokens = {}, seen_equals = false }
          set_align_max_col_width = 0
        end
      elseif upper == "VALUES" then
        reset_clauses()
        in_values_clause = true
      elseif upper == "ON" and in_join_clause then
        in_on_clause = true
        -- Phase 1: on_condition_style stacked_indent - set flag to add newline before first condition
        local on_cond_style = config.on_condition_style or "inline"
        if on_cond_style == "stacked_indent" then
          pending_on_stacked_indent_newline = true
        end
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
        in_update_statement = true
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
      elseif upper == "CREATE" then
        -- Track CREATE for DDL statements
        pending_create = true
        reset_clauses()
      elseif upper == "TABLE" and pending_create then
        -- CREATE TABLE detected - will enter column definitions at next open paren
        in_create_table = true
        pending_create = false
      elseif pending_create then
        -- CREATE followed by something other than TABLE (VIEW, PROCEDURE, etc.)
        pending_create = false
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
      -- Phase 1: Check if this is CROSS APPLY or OUTER APPLY
      -- Look ahead to see if CROSS or OUTER is followed by APPLY
      elseif is_apply_modifier(upper) then
        -- Check if next keyword token is APPLY
        local next_is_apply = false
        for j = i + 1, #tokens do
          local next_token = tokens[j]
          if next_token.type == "keyword" then
            if is_apply_keyword(next_token.text) then
              next_is_apply = true
            end
            break
          end
        end

        if next_is_apply then
          -- This is CROSS APPLY or OUTER APPLY
          if not pending_apply then
            if config.cross_apply_newline ~= false then
              needs_newline = true
              current_indent = base_indent
            end
          end
          pending_apply = true
        else
          -- This is a join modifier (CROSS JOIN or OUTER JOIN)
          if not pending_join then
            needs_newline = true
            current_indent = base_indent
            join_modifiers = {}
            if config.empty_line_before_join then
              add_empty_line_after_flush = true
            end
          end
          pending_join = true
          table.insert(join_modifiers, upper)

          -- Phase 1: join_keyword_style - skip OUTER in short mode
          local join_style = config.join_keyword_style or "preserve"
          if join_style == "short" and upper == "OUTER" then
            skip_token = true
          end
        end
      -- Check if this is a join modifier or JOIN keyword (excluding CROSS/OUTER which are handled above)
      elseif token.is_join_modifier or is_join_modifier(upper) then
        -- This is a join modifier (INNER, LEFT, RIGHT, FULL, NATURAL)
        -- Add newline if this is the START of a new join clause
        if not pending_join then
          needs_newline = true
          current_indent = base_indent
          -- Reset join modifiers for new join clause
          join_modifiers = {}

          -- Phase 1: empty_line_before_join option
          if config.empty_line_before_join then
            add_empty_line_after_flush = true  -- Add blank line after flushing current content
          end
        end
        pending_join = true
        -- Track this modifier for join_keyword_style processing
        table.insert(join_modifiers, upper)

        -- Phase 1: join_keyword_style - skip INNER in short mode
        -- "preserve" (default) keeps original, "full" expands, "short" abbreviates
        local join_style = config.join_keyword_style or "preserve"
        if join_style == "short" and upper == "INNER" then
          skip_token = true  -- Skip INNER in short mode
        end
      elseif is_apply_keyword(upper) then
        -- This is APPLY keyword (part of CROSS APPLY or OUTER APPLY)
        -- Reset pending_apply flag
        pending_apply = false
      elseif is_join_keyword(upper) then
        -- This is JOIN - only add newline if no modifier preceded it
        if not pending_join then
          needs_newline = true
          current_indent = base_indent
          -- Reset join modifiers for standalone JOIN
          join_modifiers = {}

          -- Phase 1: empty_line_before_join option
          if config.empty_line_before_join then
            add_empty_line_after_flush = true  -- Add blank line after flushing current content
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
        -- Special handling for FROM after DELETE - controlled by delete_from_newline option
        elseif token.is_delete_from then
          if config.delete_from_newline then
            needs_newline = true
            current_indent = base_indent
          end
          -- If delete_from_newline is false, FROM stays on same line as DELETE
        -- Special handling for FROM clause - controlled by from_newline option
        elseif upper == "FROM" then
          if config.from_newline ~= false then  -- Default is true
            needs_newline = true
            current_indent = base_indent
          end
          -- If from_newline is false, FROM stays on same line
        -- Special handling for WHERE clause - controlled by where_newline option
        elseif upper == "WHERE" then
          if config.where_newline ~= false then  -- Default is true
            needs_newline = true
            current_indent = base_indent
          end
          -- If where_newline is false, WHERE stays on same line
        -- Special handling for GROUP (BY) clause - controlled by group_by_newline option
        elseif upper == "GROUP" then
          if config.group_by_newline ~= false then  -- Default is true
            needs_newline = true
            current_indent = base_indent
          end
          -- If group_by_newline is false, GROUP BY stays on same line
        -- Special handling for HAVING clause - controlled by having_newline option
        elseif upper == "HAVING" then
          if config.having_newline ~= false then  -- Default is true
            needs_newline = true
            current_indent = base_indent
          end
          -- If having_newline is false, HAVING stays on same line
        -- Special handling for ORDER (BY) clause - controlled by order_by_newline option
        elseif upper == "ORDER" and not token.in_over_clause then
          if config.order_by_newline ~= false then  -- Default is true
            needs_newline = true
            current_indent = base_indent
          end
          -- If order_by_newline is false, ORDER BY stays on same line
        else
          needs_newline = true
          current_indent = base_indent
          pending_join = false

          -- Phase 3: blank_line_before_clause option
          -- Only add blank lines at top level (not inside subqueries)
          local pd = token.paren_depth or 0
          if config.blank_line_before_clause and pd == 0 then
            -- Flag to add blank line after flushing current content
            add_empty_line_after_flush = true
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

    -- Handle DELETE alias newline (e.g., DELETE s FROM ...)
    if token.is_delete_alias and config.delete_alias_newline then
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
    end

    -- Handle ON clause positioning
    if is_on_keyword(token) and not config.join_on_same_line then
      needs_newline = true
      current_indent = token.indent_level or 0
      extra_indent = 1
    end

    -- Handle AND/OR positioning in WHERE clause
    -- Phase 1: where_condition_style controls whether conditions are stacked
    local where_style = config.where_condition_style or "stacked"
    if in_where_clause and is_and_or(token) and where_style ~= "inline" then
      -- stacked and stacked_indent both stack conditions
      if config.and_or_position == "leading" then
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = config.where_and_or_indent or 1  -- Phase 1: configurable indent
      end
    end

    -- Phase 1: Handle AND/OR positioning in ON clause (join conditions)
    -- Respect on_condition_style: inline keeps everything on one line, stacked/stacked_indent stack
    local on_cond_style = config.on_condition_style or "inline"
    if in_on_clause and is_and_or(token) and on_cond_style ~= "inline" then
      -- stacked and stacked_indent both stack conditions
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
    -- Phase 1: select_list_style controls whether columns are stacked or inline
    if token.type == "comma" and in_select_list then
      local list_style = config.select_list_style or "stacked"
      -- Note: stacked_indent also stacks columns (it's stacked with first on new line)
      if (list_style == "stacked" or list_style == "stacked_indent") and config.comma_position == "leading" then
        -- Comma starts new line (stacked style with leading commas)
        needs_newline = true
        current_indent = token.indent_level or 0
        extra_indent = 1
      end
      -- For trailing, we handle after adding the token
    end

    -- Handle comma for table lists (FROM)
    -- Phase 1: from_table_style controls whether tables are stacked or inline
    if token.type == "comma" and in_from_clause then
      local from_style = config.from_table_style or "inline"
      -- Note: stacked_indent also stacks tables (it's stacked with first on new line)
      if (from_style == "stacked" or from_style == "stacked_indent") and config.comma_position == "leading" then
        -- Comma starts new line (stacked style with leading commas)
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

    -- Check if we should skip this token early (for join_keyword_style)
    -- This must be done before adding spaces/newlines
    if skip_token then
      -- Reset skip flag and don't output this token
      -- Also don't update prev_token so spacing works correctly
      skip_token = false
      goto continue
    end

    -- Apply newline if needed
    if needs_newline and #current_line > 0 then
      -- Finish current line
      local line_text = table.concat(current_line, "")
      -- Only add if not just whitespace
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}

      -- Add empty line after flush if flagged (for empty_line_before_join)
      if add_empty_line_after_flush and #result > 0 then
        table.insert(result, "")
      end

      -- Start new line with indent
      local indent = get_indent(config, current_indent + extra_indent)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
    else
      -- Add space between tokens if needed (but skip if we just started a line with indent)
      if not skip_space_before and needs_space_before(prev_token, token, config) then
        table.insert(current_line, " ")
      end
    end

    -- Add the token text with proper casing (Phase 3)
    local formatted_text = apply_token_casing(token, config)

    -- Phase 1: join_keyword_style "full" - insert OUTER before JOIN if needed
    -- "preserve" (default) keeps original, "full" expands, "short" abbreviates
    local join_style = config.join_keyword_style or "preserve"
    if is_join_keyword(string.upper(token.text)) and join_style == "full" then
      -- Check what modifiers we have
      local has_outer = false
      local has_inner = false
      local has_left_right_full = false

      for _, mod in ipairs(join_modifiers) do
        if mod == "OUTER" then has_outer = true end
        if mod == "INNER" then has_inner = true end
        if mod == "LEFT" or mod == "RIGHT" or mod == "FULL" then has_left_right_full = true end
      end

      -- For standalone JOIN (no modifiers), add INNER
      if #join_modifiers == 0 then
        local case_fn = (config.keyword_case == "lower") and string.lower or string.upper
        table.insert(current_line, case_fn("INNER") .. " ")
      -- For LEFT/RIGHT/FULL JOIN without OUTER, add OUTER
      elseif has_left_right_full and not has_outer then
        local case_fn = (config.keyword_case == "lower") and string.lower or string.upper
        table.insert(current_line, case_fn("OUTER") .. " ")
      end
      -- Reset join_modifiers after processing JOIN
      join_modifiers = {}
    end

    -- Phase 3: use_as_keyword - insert AS before aliases that don't have it
    if token.needs_as_keyword then
      local case_fn = (config.keyword_case == "lower") and string.lower or string.upper
      table.insert(current_line, case_fn("AS") .. " ")
    end

    -- Phase 2: insert_into_keyword - insert INTO before table name if missing
    if token.needs_into_keyword and config.insert_into_keyword then
      local case_fn = (config.keyword_case == "lower") and string.lower or string.upper
      table.insert(current_line, case_fn("INTO") .. " ")
    end

    -- Phase 2: delete_from_keyword - insert FROM before table name if missing
    if token.needs_from_keyword and config.delete_from_keyword then
      local case_fn = (config.keyword_case == "lower") and string.lower or string.upper
      local from_keyword = case_fn("FROM")

      -- Respect delete_from_newline setting
      if config.delete_from_newline then
        -- Flush current line (DELETE) and put FROM on new line
        local line_text = table.concat(current_line, "")
        -- Trim trailing whitespace before flushing
        line_text = line_text:gsub("%s+$", "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
        current_line = {}
        -- Add FROM with proper indentation on new line
        local base_indent = token.indent_level or 0
        local indent = get_indent(config, base_indent)
        table.insert(current_line, indent .. from_keyword .. " ")
        line_just_started = false  -- We added content, not just indent
      else
        -- Keep FROM on same line as DELETE
        table.insert(current_line, from_keyword .. " ")
      end
    end

    table.insert(current_line, formatted_text)

    -- Phase 1: select_list_style stacked_indent - set flag to add newline before first column
    local select_list_style = config.select_list_style or "stacked"
    if token.type == "keyword" and string.upper(token.text) == "SELECT" and select_list_style == "stacked_indent" then
      -- Set flag - next token (first column) will trigger newline
      pending_stacked_indent_newline = true
    end

    -- Phase 1: Handle trailing AND/OR in WHERE clause (newline after AND/OR)
    local where_cond_style = config.where_condition_style or "stacked"
    if in_where_clause and is_and_or(token) and where_cond_style ~= "inline" and config.and_or_position == "trailing" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent the next condition
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + (config.where_and_or_indent or 1))
      if indent ~= "" then
        table.insert(current_line, indent)
      end
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 1: Handle trailing AND/OR in ON clause (newline after AND/OR)
    local on_cond_style_trailing = config.on_condition_style or "inline"
    if in_on_clause and is_and_or(token) and on_cond_style_trailing ~= "inline" and config.on_and_position == "trailing" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent the next condition
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
      line_just_started = true  -- Skip space before next token
    end

    -- Handle trailing comma newline in SELECT list
    -- Phase 1: select_list_style controls whether columns are stacked or inline
    -- Only at paren_depth 0 (not inside function calls like COUNT(*), COALESCE(a, b), etc.)
    local paren_depth = token.paren_depth or 0
    -- Note: stacked_indent also stacks columns (it's stacked with first on new line)
    if token.type == "comma" and in_select_list and (select_list_style == "stacked" or select_list_style == "stacked_indent") and config.comma_position == "trailing" and paren_depth == 0 then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Handle trailing comma newline in FROM list (tables)
    -- Phase 1: from_table_style controls whether tables are stacked or inline
    -- Only at paren_depth 0 (not inside subqueries)
    local from_style = config.from_table_style or "inline"
    -- Note: stacked_indent also stacks tables (it's stacked with first on new line)
    if token.type == "comma" and in_from_clause and (from_style == "stacked" or from_style == "stacked_indent") and config.comma_position == "trailing" and paren_depth == 0 then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        table.insert(result, line_text)
      end
      current_line = {}
      -- Indent continuation (base indent from subquery + 1 for table list)
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
      line_just_started = true  -- Skip space before next token
    end

    -- Handle trailing comma newline in SET clause (UPDATE assignments)
    -- Phase 2: update_set_style stacked
    if token.type == "comma" and in_set_clause and config.update_set_style == "stacked" then
      local line_text = table.concat(current_line, "")
      if line_text:match("%S") then
        -- If alignment is active, buffer this assignment instead of outputting
        if set_align_active then
          -- Parse the line to extract column name and value
          -- Format: "SET col = value," or "  col = value," (first has SET, rest have indent)
          -- The comma is already in line_text because it was added before this check
          local indent_part, prefix, col_part, value_part

          -- First try with SET prefix (first assignment)
          indent_part, prefix, col_part, value_part = line_text:match("^(%s*)(SET%s+)([^=]+)%s*=%s*(.+),$")
          if not indent_part then
            -- Try without SET (subsequent assignments)
            indent_part, col_part, value_part = line_text:match("^(%s*)([^=]+)%s*=%s*(.+),$")
            prefix = ""
          end
          if not indent_part then
            -- Try without trailing comma
            indent_part, prefix, col_part, value_part = line_text:match("^(%s*)(SET%s+)([^=]+)%s*=%s*(.+)$")
            if not indent_part then
              indent_part, col_part, value_part = line_text:match("^(%s*)([^=]+)%s*=%s*(.+)$")
              prefix = ""
            end
          end
          if col_part then
            col_part = col_part:match("^%s*(.-)%s*$") -- trim whitespace
            if #col_part > set_align_max_col_width then
              set_align_max_col_width = #col_part
            end
            table.insert(set_align_buffer, {
              column_name = col_part,
              value_text = value_part or "",
              indent = (indent_part or "") .. (prefix or "")
            })
          else
            -- Fallback: output as-is if parsing fails
            table.insert(result, line_text)
          end
        else
          table.insert(result, line_text)
        end
      end
      current_line = {}
      -- Indent continuation for SET assignments
      local base_indent = token.indent_level or 0
      local indent = get_indent(config, base_indent + 1)
      if indent ~= "" then
        table.insert(current_line, indent)
      end
      line_just_started = true  -- Skip space before next token
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
      line_just_started = true  -- Skip space before next token
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
      line_just_started = true  -- Skip space before next token
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
      line_just_started = true  -- Skip space before next token
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

    -- Phase 4: CREATE TABLE column newline handling
    -- Track parenthesis depth for CREATE TABLE
    if in_create_table then
      if token.type == "paren_open" then
        create_table_paren_depth = create_table_paren_depth + 1
      elseif token.type == "paren_close" then
        create_table_paren_depth = create_table_paren_depth - 1
        if create_table_paren_depth <= 0 then
          -- Exiting CREATE TABLE column definitions
          in_create_table = false
          create_table_paren_depth = 0
        end
      end
    end

    -- Phase 4: create_table_column_newline - each column definition on new line
    if token.type == "comma" and in_create_table and create_table_paren_depth == 1 and config.create_table_column_newline ~= false then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 4: IN clause parenthesis and stacked_indent handling
    -- Track when we enter IN (...)
    if pending_in and token.type == "paren_open" then
      pending_in = false
      in_in_clause = true
      in_clause_paren_depth = 1

      -- Check for stacked_indent - need newline after opening paren
      local in_style = config.in_list_style or config.where_in_list_style or "inline"
      if in_style == "stacked_indent" then
        pending_in_stacked_indent_newline = true
      end
    elseif in_in_clause then
      if token.type == "paren_open" then
        in_clause_paren_depth = in_clause_paren_depth + 1
      elseif token.type == "paren_close" then
        in_clause_paren_depth = in_clause_paren_depth - 1
        if in_clause_paren_depth <= 0 then
          in_in_clause = false
          in_clause_paren_depth = 0
          pending_in_stacked_indent_newline = false
        end
      end
    end

    -- Reset pending_in if we see something other than paren_open after IN
    if pending_in and token.type ~= "paren_open" and token.type ~= "whitespace" then
      pending_in = false
    end

    -- Track IN clause for in_list_style (AFTER the reset check above)
    if token.type == "keyword" and string.upper(token.text) == "IN" then
      pending_in = true
    end

    -- Phase 4: in_list_style - each value in IN clause on new line
    local in_style = config.in_list_style or config.where_in_list_style or "inline"
    if token.type == "comma" and in_in_clause and in_clause_paren_depth == 1 and in_style ~= "inline" then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 2: INSERT column list parenthesis tracking
    -- Track when we enter INSERT INTO table (...) column list
    if in_insert_columns and not in_insert_columns_paren and token.type == "paren_open" then
      -- Entering column list parentheses
      in_insert_columns_paren = true
      insert_columns_paren_depth = 1

      -- Check for stacked_indent - need newline after opening paren
      local insert_col_style = config.insert_columns_style or "inline"
      if insert_col_style == "stacked_indent" then
        pending_insert_columns_stacked_indent_newline = true
      end
    elseif in_insert_columns_paren then
      if token.type == "paren_open" then
        insert_columns_paren_depth = insert_columns_paren_depth + 1
      elseif token.type == "paren_close" then
        insert_columns_paren_depth = insert_columns_paren_depth - 1
        if insert_columns_paren_depth <= 0 then
          -- Exiting INSERT column list
          in_insert_columns_paren = false
          in_insert_columns = false  -- No longer in INSERT context after column list
          insert_columns_paren_depth = 0
          pending_insert_columns_stacked_indent_newline = false
        end
      end
    end

    -- Phase 2: insert_columns_style - each column in INSERT column list on new line
    local insert_col_style = config.insert_columns_style or "inline"
    if token.type == "comma" and in_insert_columns_paren and insert_columns_paren_depth == 1 and insert_col_style ~= "inline" then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 2: VALUES parenthesis tracking
    -- Track when we enter VALUES (...) value list
    if in_values_clause and not in_values_paren and token.type == "paren_open" then
      -- Entering VALUES parentheses
      in_values_paren = true
      values_paren_depth = 1

      -- Check for stacked_indent - need newline after opening paren
      local values_style = config.insert_values_style or "inline"
      if values_style == "stacked_indent" then
        pending_values_stacked_indent_newline = true
      end
    elseif in_values_paren then
      if token.type == "paren_open" then
        values_paren_depth = values_paren_depth + 1
      elseif token.type == "paren_close" then
        values_paren_depth = values_paren_depth - 1
        if values_paren_depth <= 0 then
          -- Exiting VALUES value list
          in_values_paren = false
          values_paren_depth = 0
          pending_values_stacked_indent_newline = false
          -- Don't reset in_values_clause here - might have more value rows
        end
      end
    end

    -- Phase 2: insert_values_style - each value in VALUES clause on new line
    local values_style = config.insert_values_style or "inline"
    if token.type == "comma" and in_values_paren and values_paren_depth == 1 and values_style ~= "inline" then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 2: CTE column list tracking
    -- Detect CTE name token and set up for potential column list
    if token.is_cte_name then
      in_cte_columns = true  -- Expecting optional column list or AS
    end

    -- AS keyword ends CTE column context (whether or not there was a column list)
    if token.is_cte_as and in_cte_columns then
      in_cte_columns = false
      in_cte_columns_paren = false
      cte_columns_paren_depth = 0
      pending_cte_columns_stacked_indent_newline = false
    end

    -- Track when we enter CTE column list parentheses
    if in_cte_columns and not in_cte_columns_paren and token.type == "paren_open" then
      -- Entering CTE column list parentheses
      in_cte_columns_paren = true
      cte_columns_paren_depth = 1

      -- Check for stacked_indent - need newline after opening paren
      local cte_col_style = config.cte_columns_style or "inline"
      if cte_col_style == "stacked_indent" then
        pending_cte_columns_stacked_indent_newline = true
      end
    elseif in_cte_columns_paren then
      if token.type == "paren_open" then
        cte_columns_paren_depth = cte_columns_paren_depth + 1
      elseif token.type == "paren_close" then
        cte_columns_paren_depth = cte_columns_paren_depth - 1
        if cte_columns_paren_depth <= 0 then
          -- Exiting CTE column list (but still in_cte_columns until AS)
          in_cte_columns_paren = false
          cte_columns_paren_depth = 0
          pending_cte_columns_stacked_indent_newline = false
        end
      end
    end

    -- Phase 2: cte_columns_style - each column in CTE column list on new line
    local cte_col_style = config.cte_columns_style or "inline"
    if token.type == "comma" and in_cte_columns_paren and cte_columns_paren_depth == 1 and cte_col_style ~= "inline" then
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
      line_just_started = true  -- Skip space before next token
    end

    -- Phase 4: function_arg_style - track function calls
    -- When we see paren_open after function keyword, push onto function call stack
    local func_style = config.function_arg_style or "inline"
    if pending_function_call and token.type == "paren_open" then
      pending_function_call = false
      table.insert(function_call_stack, {
        paren_depth = 1,
        arg_count = 1,  -- First arg starts
        base_indent = token.indent_level or 0
      })
      -- For stacked_indent, set flag to add newline after this paren
      if func_style == "stacked_indent" then
        pending_function_stacked_indent_newline = true
      end
    elseif #function_call_stack > 0 then
      -- Track parenthesis depth within function calls
      local current_func = function_call_stack[#function_call_stack]
      if token.type == "paren_open" then
        current_func.paren_depth = current_func.paren_depth + 1
      elseif token.type == "paren_close" then
        current_func.paren_depth = current_func.paren_depth - 1
        if current_func.paren_depth <= 0 then
          -- Exit this function call
          table.remove(function_call_stack)
        end
      elseif token.type == "comma" and current_func.paren_depth == 1 then
        -- Comma at function's own paren depth - this separates arguments
        current_func.arg_count = current_func.arg_count + 1
      end
    end

    -- Reset pending_function_call if we see something other than paren_open
    if pending_function_call and token.type ~= "paren_open" and token.type ~= "whitespace" then
      pending_function_call = false
    end

    -- Detect function keyword and set pending flag (AFTER reset check so it persists to next token)
    if token.keyword_category == "function" then
      pending_function_call = true
    end

    -- Phase 4: function_arg_style - handle comma in function calls for stacked style
    local func_style = config.function_arg_style or "inline"
    if token.type == "comma" and #function_call_stack > 0 and func_style ~= "inline" then
      local current_func = function_call_stack[#function_call_stack]
      -- Only stack if we're at the function's direct level (paren_depth == 1)
      -- and the function has multiple args (don't stack single arg functions)
      if current_func.paren_depth == 1 and current_func.arg_count >= 1 then
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
        current_line = {}
        local base_indent = current_func.base_indent or 0
        local indent = get_indent(config, base_indent + 1)
        if indent ~= "" then
          table.insert(current_line, indent)
        end
        line_just_started = true
      end
    end

    -- Handle semicolon - end of statement
    if token.type == "semicolon" then
      -- Flush SET alignment buffer if active (UPDATE ... SET ... ;)
      if set_align_active then
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          -- Parse the line to extract column name and value
          local indent_part, prefix, col_part, value_part
          -- First try with SET prefix (single assignment case)
          indent_part, prefix, col_part, value_part = line_text:match("^(%s*)(SET%s+)([^=]+)%s*=%s*(.+)$")
          if not indent_part then
            -- Try without SET
            indent_part, col_part, value_part = line_text:match("^(%s*)([^=]+)%s*=%s*(.+)$")
            prefix = ""
          end
          if col_part then
            col_part = col_part:match("^%s*(.-)%s*$") -- trim
            if #col_part > set_align_max_col_width then
              set_align_max_col_width = #col_part
            end
            table.insert(set_align_buffer, {
              column_name = col_part,
              value_text = value_part or "",
              indent = (indent_part or "") .. (prefix or "")
            })
          end
        end
        if #set_align_buffer > 0 then
          flush_set_align_buffer(set_align_buffer, result, set_align_max_col_width, config)
        end
        current_line = {}
        set_align_active = false
        set_align_buffer = {}
        set_align_current = nil
        in_update_statement = false
        -- Add semicolon to the last line
        if #result > 0 then
          result[#result] = result[#result] .. ";"
        end
      else
        local line_text = table.concat(current_line, "")
        if line_text:match("%S") then
          table.insert(result, line_text)
        end
      end
      current_line = {}
      current_indent = 0
      reset_all_state()

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
      reset_all_state()

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

  -- Post-process: apply FROM alias alignment if enabled
  result = align_from_aliases(result, config)

  -- Post-process: limit consecutive blank lines
  local max_blank = config.max_consecutive_blank_lines
  if max_blank and max_blank >= 0 then
    local filtered = {}
    local blank_count = 0
    for _, line in ipairs(result) do
      if line:match("^%s*$") then
        -- This is a blank line
        blank_count = blank_count + 1
        if blank_count <= max_blank then
          table.insert(filtered, line)
        end
        -- If over the limit, skip this blank line
      else
        -- Non-blank line
        blank_count = 0
        table.insert(filtered, line)
      end
    end
    result = filtered
  end

  return table.concat(result, "\n")
end

return Output
