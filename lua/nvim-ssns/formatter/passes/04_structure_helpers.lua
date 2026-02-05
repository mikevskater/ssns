---@class StructurePassHelpers
---Helper functions and constants for the structure pass
local M = {}

-- =============================================================================
-- Constants
-- =============================================================================

M.MAJOR_CLAUSES = {
  SELECT = true, FROM = true, WHERE = true,
  ["GROUP"] = true, ["ORDER"] = true, HAVING = true,
  UNION = true, INTERSECT = true, EXCEPT = true,
  INSERT = true, UPDATE = true, DELETE = true,
  SET = true, VALUES = true, WITH = true,
  MERGE = true, USING = true, OUTPUT = true,
}

M.CLAUSE_NEWLINE_CONFIG = {
  FROM = "from_newline",
  WHERE = "where_newline",
  ["GROUP"] = "group_by_newline",
  ["ORDER"] = "order_by_newline",
  HAVING = "having_newline",
  SET = "update_set_newline",
  VALUES = "insert_values_newline",
  OUTPUT = "output_clause_newline",
}

M.JOIN_MODIFIERS = {
  INNER = true, LEFT = true, RIGHT = true, FULL = true,
  OUTER = true, CROSS = true, NATURAL = true,
}

-- =============================================================================
-- Helper Functions
-- =============================================================================

function M.get_upper(token)
  if token.type == "keyword" then
    return string.upper(token.text)
  end
  return nil
end

function M.is_and_or(token)
  if token.type ~= "keyword" then return false end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

function M.is_comma(token)
  return token.type == "comma"
end

-- =============================================================================
-- Comma Processing
-- =============================================================================

---Process comma token for stacked styles
---@param token table The comma token
---@param state table The current state
---@param config table The formatter config
---@param tokens table All tokens
---@param i number Current token index
---@return boolean add_newline Whether to add a trailing newline
---@return number next_indent The indent level for the next token
function M.process_comma(token, state, config, tokens, i)
  local add_newline = false
  local next_indent = state.base_indent + 1

  -- CTE compact mode: suppress all stacked styles inside CTE body
  -- MERGE compact mode: suppress all stacked styles inside MERGE statement
  local in_cte_compact = token.in_cte_body and config.cte_style == "compact"
  local in_merge_compact = token.in_merge and config.merge_style == "compact"

  if state.in_select_list and state.paren_depth == state.select_paren_depth then
    local style = config.select_list_style or "inline"
    if not in_cte_compact and (style == "stacked" or style == "stacked_indent") then
      add_newline = true
    end
  elseif state.in_from_clause and not state.in_on_clause then
    local style = config.from_table_style or "inline"
    if not in_cte_compact and (style == "stacked" or style == "stacked_indent") then
      add_newline = true
    end
  elseif state.in_group_by then
    local style = config.group_by_style or "inline"
    if not in_cte_compact and style == "stacked" then
      add_newline = true
    end
  elseif state.in_order_by and not state.in_over_clause then
    local style = config.order_by_style or "inline"
    if not in_cte_compact and style == "stacked" then
      add_newline = true
    end
  elseif state.in_set_clause then
    local style = config.update_set_style or "stacked"
    if not in_cte_compact and not in_merge_compact and style == "stacked" then
      add_newline = true
    end
  elseif state.in_in_list and state.paren_depth == state.in_list_paren_depth then
    local style = config.where_in_list_style or config.in_list_style or "inline"
    if not in_cte_compact and (style == "stacked" or style == "stacked_indent") then
      add_newline = true
      next_indent = state.base_indent + 2
    end
  elseif state.in_insert_columns then
    local style = config.insert_columns_style or "inline"
    if not in_cte_compact and (style == "stacked" or style == "stacked_indent") then
      add_newline = true
    end
  elseif state.in_values_clause and state.paren_depth == state.values_paren_depth then
    local style = config.insert_values_style or "inline"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
    end
  end

  -- Function argument style - stacked puts each argument on new line
  -- Only applies to commas marked as function arg separators by expressions pass
  if token.is_function_arg_separator then
    local style = config.function_arg_style or "inline"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- CTE columns style - stacked puts each column on new line
  if token.is_cte_column_separator then
    local style = config.cte_columns_style or "inline"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- CREATE TABLE column definitions - each column on new line if configured
  if token.is_create_table_column_separator then
    add_newline, next_indent = M.process_create_table_comma(token, state, config, tokens, i)
  end

  -- INSERT multi-row VALUES - each row on new line if configured
  -- This handles: VALUES (1, 'a'), (2, 'b'), (3, 'c')
  if token.is_values_row_separator then
    local style = config.insert_multi_row_style or "stacked"
    if style == "stacked" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- INDEX column list - each column on new line if configured
  -- Applies to both CREATE INDEX ... (columns) and INCLUDE (columns)
  if token.is_index_column_separator or token.is_index_include_separator then
    local style = config.index_column_style or "inline"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- Procedure parameter list - each param on new line if configured
  if token.is_procedure_param_separator then
    local style = config.procedure_param_style or "stacked"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- Function parameter list - each param on new line if configured
  if token.is_function_param_separator then
    local style = config.function_param_style or "stacked"
    if style == "stacked" or style == "stacked_indent" then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  -- ALTER TABLE operation separator - each operation on new line if expanded style
  if token.is_alter_table_separator then
    local style = config.alter_table_style or "expanded"
    if style == "expanded" then
      add_newline = true
      next_indent = state.base_indent
    end
  end

  return add_newline, next_indent
end

---Process CREATE TABLE comma (column/constraint separator)
---@param token table The comma token
---@param state table The current state
---@param config table The formatter config
---@param tokens table All tokens
---@param i number Current token index
---@return boolean add_newline
---@return number next_indent
function M.process_create_table_comma(token, state, config, tokens, i)
  local add_newline = false
  local next_indent = state.base_indent + 1

  -- Check if next token is a table-level constraint
  local next_is_constraint = false
  for j = i + 1, #tokens do
    local next_tok = tokens[j]
    if next_tok.type == "whitespace" or next_tok.type == "newline" then
      -- skip
    elseif next_tok.is_table_constraint_start then
      next_is_constraint = true
      break
    else
      break
    end
  end

  if next_is_constraint then
    -- Comma before a constraint
    -- If create_table_constraint_newline = true (default): always newline
    -- If create_table_constraint_newline = false: follow create_table_column_newline
    local constraint_newline = config.create_table_constraint_newline
    if constraint_newline ~= false then
      -- Constraint newline is enabled (default)
      add_newline = true
      next_indent = state.base_indent + 1
    else
      -- Constraint newline is disabled - use column newline setting
      local column_newline = config.create_table_column_newline
      if column_newline ~= false then
        add_newline = true
        next_indent = state.base_indent + 1
      end
    end
  else
    -- Regular column separator: use create_table_column_newline setting
    local column_newline = config.create_table_column_newline
    -- Default to true if not specified
    if column_newline ~= false then
      add_newline = true
      next_indent = state.base_indent + 1
    end
  end

  return add_newline, next_indent
end

-- =============================================================================
-- Stacked First-Item Newline Processing
-- =============================================================================

---Apply pending stacked_indent first-item newlines
---@param token table The current token
---@param state table The current state
---@param config table The formatter config
function M.apply_pending_first_item_newlines(token, state, config)
  -- Skip whitespace, newlines, commas, and parens
  local skip_types = {whitespace=1, newline=1, comma=1, paren_open=1, paren_close=1}
  if skip_types[token.type] then
    return
  end

  local upper = token.type == "keyword" and string.upper(token.text) or ""

  -- CTE compact mode: suppress stacked_indent first-item newlines inside CTE body
  local in_cte_compact = token.in_cte_body and config.cte_style == "compact"

  -- SELECT stacked_indent: skip SELECT and modifiers (DISTINCT, TOP, ALL, numbers after TOP, PERCENT, TIES, WITH)
  if state.pending_select_first then
    local is_modifier = upper == "SELECT" or upper == "DISTINCT" or upper == "TOP" or upper == "ALL"
                     or upper == "PERCENT" or upper == "TIES" or upper == "WITH"
                     or token.type == "number"
    if not is_modifier then
      if not in_cte_compact then
        token.newline_before = true
        token.indent_level = state.base_indent + 1
      end
      state.pending_select_first = false
    end
  end

  -- FROM stacked_indent: first table (skip FROM keyword)
  if state.pending_from_first and upper ~= "FROM" then
    if not in_cte_compact then
      token.newline_before = true
      token.indent_level = state.base_indent + 1
    end
    state.pending_from_first = false
  end

  -- WHERE stacked_indent: first condition (skip WHERE keyword)
  if state.pending_where_first and upper ~= "WHERE" then
    if not in_cte_compact then
      token.newline_before = true
      token.indent_level = state.base_indent + 1
    end
    state.pending_where_first = false
  end

  -- ON stacked_indent: first condition (skip ON keyword itself)
  if state.pending_on_first and upper ~= "ON" then
    if not in_cte_compact then
      token.newline_before = true
      -- +1 for join_indent_style, +1 for ON offset
      local join_indent = config.join_indent_style == "indent" and 1 or 0
      -- nested_join_indent: extra indent for ON first condition inside subqueries
      local nested_indent = (config.nested_join_indent or 0) * (token.subquery_depth or 0)
      token.indent_level = state.base_indent + join_indent + nested_indent + 2
    end
    state.pending_on_first = false
  end

  -- IN stacked_indent: first value after ( (skip IN keyword and paren)
  if state.pending_in_first and upper ~= "IN" then
    token.newline_before = true
    token.indent_level = state.base_indent + 2
    state.pending_in_first = false
  end

  -- INSERT columns stacked_indent: first column after ( (skip INSERT, INTO, table, paren)
  if state.pending_insert_columns_first and upper ~= "INSERT" and upper ~= "INTO" then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_insert_columns_first = false
  end

  -- VALUES stacked_indent: first value after ( (skip VALUES keyword)
  if state.pending_values_first and upper ~= "VALUES" then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_values_first = false
  end

  -- BETWEEN stacked_indent: first value after BETWEEN
  if state.pending_between_first and upper ~= "BETWEEN" then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_between_first = false
  end

  -- CTE columns stacked_indent: first column after (
  if state.pending_cte_columns_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_cte_columns_first = false
  end

  -- Function args stacked_indent: first arg after (
  if state.pending_function_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_function_first = false
  end

  -- Index columns stacked_indent: first column after (
  if state.pending_index_columns_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_index_columns_first = false
  end

  -- Index INCLUDE columns stacked_indent: first column after (
  if state.pending_index_include_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_index_include_first = false
  end

  -- Procedure params stacked_indent: first param after (
  if state.pending_procedure_params_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_procedure_params_first = false
  end

  -- Function params stacked_indent: first param after (
  if state.pending_function_params_first then
    token.newline_before = true
    token.indent_level = state.base_indent + 1
    state.pending_function_params_first = false
  end
end

-- =============================================================================
-- State Management
-- =============================================================================

---Create initial state for structure pass
---@return table state
function M.create_state()
  return {
    -- Current clause context
    current_clause = nil,
    in_select_list = false,
    in_from_clause = false,
    in_where_clause = false,
    in_group_by = false,
    in_order_by = false,
    in_having = false,
    in_set_clause = false,
    in_values_clause = false,
    in_on_clause = false,
    in_cte = false,
    in_insert_columns = false,
    in_case = false,
    in_in_list = false,
    in_between = false,
    in_over_clause = false,

    -- Paren tracking
    paren_depth = 0,
    select_paren_depth = 0,
    in_list_paren_depth = 0,
    values_paren_depth = 0,
    insert_columns_paren_depth = 0,
    over_paren_depth = 0,
    cte_columns_paren_depth = 0,

    -- Base indent from subquery depth
    base_indent = 0,

    -- Join state
    pending_join_modifier = false,
    saw_join_modifier = false,

    -- Stacked style flags
    pending_stacked_newline = false,
    stacked_indent = 0,

    -- stacked_indent: first item newline flags
    pending_select_first = false,
    pending_from_first = false,
    pending_where_first = false,
    pending_on_first = false,
    pending_in_first = false,
    pending_insert_columns_first = false,
    pending_values_first = false,
    pending_cte_columns_first = false,
    pending_between_first = false,
    pending_function_first = false,
    pending_index_columns_first = false,
    pending_index_include_first = false,
    pending_procedure_params_first = false,
    pending_function_params_first = false,

    -- Track statement boundaries to avoid extra newline at statement start
    at_statement_start = true,

    -- View body tracking for view_body_indent
    in_view_body = false,
    view_body_indent = 0,
  }
end

---Reset state on statement end
---@param state table The state to reset
function M.reset_state_on_statement_end(state)
  state.current_clause = nil
  state.in_select_list = false
  state.in_from_clause = false
  state.in_where_clause = false
  state.in_group_by = false
  state.in_order_by = false
  state.in_having = false
  state.in_set_clause = false
  state.in_values_clause = false
  state.in_on_clause = false
  state.in_cte = false
  state.in_insert_columns = false
  state.in_case = false
  state.in_in_list = false
  state.in_between = false
  state.in_over_clause = false
  state.paren_depth = 0
  state.pending_stacked_newline = false
  state.pending_join_modifier = false
  -- Reset view body state
  state.in_view_body = false
  state.view_body_indent = 0
  -- Next major clause is start of new statement
  state.at_statement_start = true
end

return M
