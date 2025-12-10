---@class StructurePass
---Pass 4: Determine newlines and indentation for each token
---
---This is the main formatting pass that decides the structure of the output.
---
---Annotations added:
---  token.newline_before     - true if newline should precede this token
---  token.indent_level       - indentation level (0, 1, 2, etc.)
---  token.empty_line_before  - true if empty line should precede this token
---  token.is_clause_start    - true if this starts a major clause
---  token.trailing_newline   - true if newline should follow this token
local StructurePass = {}

-- =============================================================================
-- Constants
-- =============================================================================

local MAJOR_CLAUSES = {
  SELECT = true, FROM = true, WHERE = true,
  ["GROUP"] = true, ["ORDER"] = true, HAVING = true,
  UNION = true, INTERSECT = true, EXCEPT = true,
  INSERT = true, UPDATE = true, DELETE = true,
  SET = true, VALUES = true, WITH = true,
  MERGE = true, USING = true, OUTPUT = true,
}

local CLAUSE_NEWLINE_CONFIG = {
  FROM = "from_newline",
  WHERE = "where_newline",
  ["GROUP"] = "group_by_newline",
  ["ORDER"] = "order_by_newline",
  HAVING = "having_newline",
  SET = "update_set_newline",
  VALUES = "insert_values_newline",
  OUTPUT = "output_clause_newline",
}

local JOIN_MODIFIERS = {
  INNER = true, LEFT = true, RIGHT = true, FULL = true,
  OUTER = true, CROSS = true, NATURAL = true,
}

-- =============================================================================
-- Helper Functions
-- =============================================================================

local function get_upper(token)
  if token.type == "keyword" then
    return string.upper(token.text)
  end
  return nil
end

local function is_and_or(token)
  if token.type ~= "keyword" then return false end
  local upper = string.upper(token.text)
  return upper == "AND" or upper == "OR"
end

local function is_comma(token)
  return token.type == "comma"
end

-- =============================================================================
-- Main Pass
-- =============================================================================

function StructurePass.run(tokens, config)
  config = config or {}

  -- State tracking
  local state = {
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

  -- Process each token
  for i, token in ipairs(tokens) do
    -- Get base indent from subquery pass, but preserve view body indent
    local token_base_indent = token.base_indent or token.subquery_depth or 0
    if state.in_view_body then
      -- In view body: add view_body_indent to base
      state.base_indent = token_base_indent + state.view_body_indent
    else
      state.base_indent = token_base_indent
    end

    -- Initialize annotations
    token.newline_before = false
    token.indent_level = state.base_indent
    token.empty_line_before = false
    token.is_clause_start = false
    token.trailing_newline = false

    -- Track parentheses
    if token.type == "paren_open" then
      state.paren_depth = state.paren_depth + 1

      -- Subquery paren style - put opening paren on new line
      if token.is_subquery_open then
        local style = config.subquery_paren_style
        if style == "new_line" or style == "newline" then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end

      -- Function arg style stacked_indent - first arg on new line
      if token.is_function_open then
        local style = config.function_arg_style or "inline"
        if style == "stacked_indent" then
          state.pending_function_first = true
        end
      end

      -- CTE parenthesis style - put opening paren on new line
      if token.is_cte_open_paren then
        local style = config.cte_parenthesis_style or "same_line"
        if style == "new_line" or style == "newline" then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end

      -- CTE columns paren - check for stacked_indent
      if token.is_cte_columns_open then
        local style = config.cte_columns_style or "inline"
        if style == "stacked_indent" then
          state.pending_cte_columns_first = true
        end
      end

      if state.in_in_list and state.in_list_paren_depth == 0 then
        state.in_list_paren_depth = state.paren_depth
        -- Check for stacked_indent - first value should be on new line
        local style = config.where_in_list_style or config.in_list_style or "inline"
        if style == "stacked_indent" then
          state.pending_in_first = true
        end
      end
      if state.in_values_clause and state.values_paren_depth == 0 then
        state.values_paren_depth = state.paren_depth
        -- Check for stacked_indent - first value should be on new line
        local style = config.insert_values_style or "inline"
        if style == "stacked_indent" then
          state.pending_values_first = true
        end
      end
      if state.in_insert_columns and state.insert_columns_paren_depth == 0 then
        state.insert_columns_paren_depth = state.paren_depth
        -- Check for stacked_indent - first column should be on new line
        local style = config.insert_columns_style or "inline"
        if style == "stacked_indent" then
          state.pending_insert_columns_first = true
        end
      end
      if state.in_over_clause and state.over_paren_depth == 0 then
        state.over_paren_depth = state.paren_depth
      end

      -- Index columns paren - check for stacked_indent
      if token.is_index_columns_open then
        local style = config.index_column_style or "inline"
        if style == "stacked_indent" then
          state.pending_index_columns_first = true
        end
      end

      -- Index INCLUDE columns paren - check for stacked_indent
      if token.is_index_include_open then
        local style = config.index_column_style or "inline"
        if style == "stacked_indent" then
          state.pending_index_include_first = true
        end
      end

      -- Procedure params paren - check for stacked_indent
      if token.is_procedure_params_open then
        local style = config.procedure_param_style or "stacked"
        if style == "stacked_indent" then
          state.pending_procedure_params_first = true
        end
      end

      -- Function params paren - check for stacked_indent
      if token.is_function_params_open then
        local style = config.function_param_style or "stacked"
        if style == "stacked_indent" then
          state.pending_function_params_first = true
        end
      end
    elseif token.type == "paren_close" then
      -- Exit paren contexts before decrementing
      if state.in_list_paren_depth > 0 and state.paren_depth == state.in_list_paren_depth then
        state.in_in_list = false
        state.in_list_paren_depth = 0
      end
      if state.over_paren_depth > 0 and state.paren_depth == state.over_paren_depth then
        state.in_over_clause = false
        state.over_paren_depth = 0
      end
      state.paren_depth = state.paren_depth - 1
      if state.paren_depth < 0 then state.paren_depth = 0 end
    end

    -- Process keywords
    if token.type == "keyword" then
      local upper = get_upper(token)

      -- OVER clause tracking (for window functions)
      if upper == "OVER" then
        state.in_over_clause = true
      end

      -- Skip most processing if inside OVER clause
      if state.in_over_clause and state.over_paren_depth > 0 then
        goto continue
      end

      -- Major clause handling
      -- Table hint WITH (NOLOCK) is NOT a major clause - skip MAJOR_CLAUSES treatment
      if MAJOR_CLAUSES[upper] and not token.is_table_hint_with then
        token.is_clause_start = true

        -- Check if this clause should start on a new line
        local config_key = CLAUSE_NEWLINE_CONFIG[upper]
        local should_newline = true

        if config_key then
          local config_val = config[config_key]
          if config_val == false then
            should_newline = false
          end
        end

        -- Special cases
        if upper == "OUTPUT" then
          should_newline = config.output_clause_newline == true
        end

        -- DELETE FROM special case - FROM after DELETE shouldn't have newline by default
        -- Use in_delete annotation from pass 1
        if upper == "FROM" and token.in_delete then
          -- delete_from_newline defaults to false
          should_newline = config.delete_from_newline == true
        end

        -- CTE compact style - suppress newlines for clauses inside CTE body
        -- cte_style: "compact" keeps CTE body inline, "expanded" (default) uses normal formatting
        if token.in_cte_body and config.cte_style == "compact" then
          -- In compact mode, don't add newlines for clauses inside CTE body
          -- (SELECT, FROM, WHERE, etc. stay on same line within CTE)
          should_newline = false
        end

        -- Don't add newline for the first major clause of a statement
        -- (the semicolon/output.lua already adds blank lines between statements)
        -- EXCEPT: If we're in a view body, always add newline for the first clause
        if should_newline and i > 1 and (not state.at_statement_start or state.in_view_body) then
          token.newline_before = true
          token.indent_level = state.base_indent
        end

        -- Clear statement start flag after first major clause
        state.at_statement_start = false

        -- Update state for new clause
        if upper == "SELECT" then
          state.in_select_list = true
          state.in_from_clause = false
          state.in_where_clause = false
          state.in_on_clause = false
          state.select_paren_depth = state.paren_depth
          -- Check for stacked_indent - first column should be on new line
          local style = config.select_list_style or "inline"
          if style == "stacked_indent" then
            state.pending_select_first = true
          end
        elseif upper == "FROM" then
          -- Check for stacked_indent - first table should be on new line
          local style = config.from_table_style or "inline"
          if style == "stacked_indent" then
            state.pending_from_first = true
          end
          state.in_select_list = false
          state.in_from_clause = true
          state.in_where_clause = false
          state.in_on_clause = false
        elseif upper == "WHERE" then
          state.in_select_list = false
          state.in_from_clause = false
          state.in_where_clause = true
          state.in_on_clause = false
          -- Check for stacked_indent - first condition should be on new line
          local style = config.where_condition_style or "stacked"
          if style == "stacked_indent" then
            state.pending_where_first = true
          end
        elseif upper == "GROUP" or upper == "ORDER" then
          state.in_select_list = false
          state.in_from_clause = false
          state.in_where_clause = false
          state.in_on_clause = false
          state.in_group_by = (upper == "GROUP")
          state.in_order_by = (upper == "ORDER")
        elseif upper == "HAVING" then
          state.in_having = true
          state.in_group_by = false
        elseif upper == "SET" then
          state.in_set_clause = true
        elseif upper == "INSERT" then
          state.in_insert_columns = true  -- Will become active when we see ( after table
        elseif upper == "VALUES" then
          state.in_values_clause = true
          state.in_insert_columns = false
        elseif upper == "WITH" then
          state.in_cte = true
        end

        state.current_clause = upper
      end

      -- CTE AS position - put AS on new line if configured
      if token.is_cte_as then
        local style = config.cte_as_position or "same_line"
        if style == "new_line" or style == "newline" then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end

      -- SELECT modifier handling (DISTINCT, TOP, INTO - when in select list)
      if state.in_select_list then
        if upper == "DISTINCT" then
          if config.select_distinct_newline then
            token.newline_before = true
            token.indent_level = state.base_indent + 1
          end
        elseif upper == "TOP" then
          if config.select_top_newline then
            token.newline_before = true
            token.indent_level = state.base_indent + 1
          end
        elseif upper == "INTO" then
          -- SELECT ... INTO #temp - INTO ends select_list
          if config.select_into_newline then
            token.newline_before = true
            token.indent_level = state.base_indent
          end
        end
      end

      -- JOIN modifier handling (INNER, LEFT, RIGHT, etc.)
      if JOIN_MODIFIERS[upper] then
        -- Check for CROSS/OUTER APPLY special handling
        local is_apply_modifier = (upper == "CROSS" or upper == "OUTER")
        local cross_apply_newline = config.cross_apply_newline ~= false  -- default true

        -- Skip newline for CROSS/OUTER when cross_apply_newline is false
        -- AND next keyword is APPLY (not JOIN)
        local skip_newline = is_apply_modifier and not cross_apply_newline

        -- OUTER following LEFT/RIGHT/FULL should NOT get newline
        -- (e.g., "LEFT OUTER JOIN" - only LEFT gets newline)
        if upper == "OUTER" and state.pending_join_modifier then
          skip_newline = true
        end

        -- CTE compact mode: suppress JOIN newlines inside CTE body
        if token.in_cte_body and config.cte_style == "compact" then
          skip_newline = true
        end

        if not skip_newline then
          -- Empty line before join if configured
          if config.empty_line_before_join and i > 1 then
            token.empty_line_before = true
          end
          token.newline_before = true
          -- join_indent_style: "indent" adds +1 level, "align" stays at base
          local join_indent = config.join_indent_style == "indent" and 1 or 0
          token.indent_level = state.base_indent + join_indent
        end

        state.pending_join_modifier = true
        state.saw_join_modifier = true
      end

      -- JOIN keyword
      if upper == "JOIN" then
        if not state.pending_join_modifier then
          -- Standalone JOIN (no modifier)
          -- Skip newline in CTE compact mode
          if not (token.in_cte_body and config.cte_style == "compact") then
            if config.empty_line_before_join and i > 1 then
              token.empty_line_before = true
            end
            token.newline_before = true
            -- join_indent_style: "indent" adds +1 level, "align" stays at base
            local join_indent = config.join_indent_style == "indent" and 1 or 0
            token.indent_level = state.base_indent + join_indent
          end
        end
        state.pending_join_modifier = false
        state.in_from_clause = true  -- JOIN is part of FROM clause
      end

      -- APPLY handling (CROSS APPLY, OUTER APPLY)
      if upper == "APPLY" then
        -- APPLY comes after CROSS or OUTER
        -- The modifier (CROSS/OUTER) already got newline
        state.in_from_clause = true
        -- Reset pending_join_modifier so next OUTER APPLY gets newline
        state.pending_join_modifier = false
      end

      -- Table hint WITH handling: WITH (NOLOCK), WITH (ROWLOCK), etc.
      -- Token must have is_table_hint_with annotation from clauses pass
      if upper == "WITH" and token.is_table_hint_with then
        local should_newline = config.from_table_hints_newline == true
        if should_newline then
          token.newline_before = true
          token.indent_level = state.base_indent + 1
        end
      end

      -- ALTER TABLE action keywords (ADD, DROP, ALTER, NOCHECK, CHECK, etc.)
      -- These keywords start a new action in ALTER TABLE statements
      if token.is_alter_table_action then
        local style = config.alter_table_style or "expanded"
        if style == "expanded" then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end

      -- DROP IF EXISTS - put IF EXISTS on new line if configured
      -- Pattern: DROP TABLE IF EXISTS name -> DROP TABLE\nIF EXISTS name
      if token.is_drop_if_exists then
        local style = config.drop_if_exists_style or "inline"
        if style == "separate" then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end

      -- VIEW body AS - set base_indent for view body
      -- Pattern: CREATE VIEW name AS SELECT ... -> view body indented
      if token.is_view_body_as then
        local indent = config.view_body_indent
        if indent == nil then indent = 1 end
        -- Set view_body_indent for all subsequent tokens in the view body
        state.view_body_indent = indent
        state.in_view_body = true
      end

      -- ON keyword
      if upper == "ON" then
        state.in_on_clause = true
        state.in_from_clause = false

        -- Skip ON newline in CTE compact mode
        if config.join_on_same_line == false and not (token.in_cte_body and config.cte_style == "compact") then
          token.newline_before = true
          -- ON indented from JOIN: +1 for join_indent_style, +1 for ON offset
          local join_indent = config.join_indent_style == "indent" and 1 or 0
          token.indent_level = state.base_indent + join_indent + 1
        end

        -- Check for stacked_indent - first condition should be on new line (skip in CTE compact mode)
        local style = config.on_condition_style or "inline"
        if style == "stacked_indent" and not (token.in_cte_body and config.cte_style == "compact") then
          state.pending_on_first = true
        end
      end

      -- IN keyword handling
      if upper == "IN" then
        state.in_in_list = true
        -- stacked_indent handled when we see the paren_open
      end

      -- BETWEEN handling
      if upper == "BETWEEN" then
        state.in_between = true
        -- Check for stacked_indent - first value should be on new line
        local style = config.where_between_style or "inline"
        if style == "stacked_indent" then
          state.pending_between_first = true
        end
      end

      -- CASE handling
      if upper == "CASE" then
        state.in_case = true
      end
      if upper == "END" and state.in_case then
        state.in_case = false
      end
      if upper == "WHEN" and state.in_case then
        if config.case_style ~= "compact" then
          token.newline_before = true
          token.indent_level = state.base_indent + 1
        end
      end
      if upper == "THEN" and state.in_case then
        if config.case_then_position == "newline" or config.case_then_position == "new_line" then
          token.newline_before = true
          token.indent_level = state.base_indent + 2
        end
      end
      if upper == "ELSE" and state.in_case then
        if config.case_style ~= "compact" then
          token.newline_before = true
          token.indent_level = state.base_indent + 1
        end
      end

      -- AND/OR handling
      if is_and_or(token) then
        -- Check if this is BETWEEN...AND
        if upper == "AND" and (token.is_between_and or state.in_between) then
          state.in_between = false
          -- BETWEEN AND - check where_between_style
          local style = config.where_between_style or "inline"
          if style == "stacked" or style == "stacked_indent" then
            token.newline_before = true
            token.indent_level = state.base_indent + 1
          end
        elseif state.in_where_clause then
          -- WHERE clause AND/OR
          local style = config.where_condition_style or "stacked"
          local position = config.where_and_position or config.and_or_position or "leading"
          -- where_and_or_indent: number of indent levels (default 1)
          local indent_levels = config.where_and_or_indent or 1

          if style == "stacked" or style == "stacked_indent" then
            if position == "leading" then
              token.newline_before = true
              token.indent_level = state.base_indent + indent_levels
            else
              -- trailing position - newline after AND/OR, indent next token
              token.trailing_newline = true
              token.skip_pending = true  -- Don't apply pending to this token
              state.pending_stacked_newline = true
              state.stacked_indent = state.base_indent + indent_levels
            end
          end
        elseif state.in_on_clause then
          -- ON clause AND/OR
          local style = config.on_condition_style or "inline"
          local position = config.on_and_position or config.and_or_position or "leading"

          if style == "stacked" or style == "stacked_indent" then
            -- ON conditions: +1 for join_indent_style, +1 for ON offset, same level for AND/OR
            local join_indent = config.join_indent_style == "indent" and 1 or 0
            local on_indent = state.base_indent + join_indent + 2
            if position == "leading" then
              token.newline_before = true
              token.indent_level = on_indent
            else
              token.trailing_newline = true
              token.skip_pending = true
              state.pending_stacked_newline = true
              state.stacked_indent = on_indent
            end
          end
        elseif config.boolean_operator_newline then
          -- Global boolean operator newline
          token.newline_before = true
          token.indent_level = state.base_indent + 1
        end
      end

      -- WHEN in MERGE (not CASE)
      if upper == "WHEN" and not state.in_case then
        if config.merge_when_newline ~= false then
          token.newline_before = true
          token.indent_level = state.base_indent
        end
      end
    end

    -- Comma handling for stacked styles
    if is_comma(token) then
      local add_newline = false
      local next_indent = state.base_indent + 1

      -- CTE compact mode: suppress all stacked styles inside CTE body
      local in_cte_compact = token.in_cte_body and config.cte_style == "compact"

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
        if not in_cte_compact and style == "stacked" then
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

      if add_newline then
        token.trailing_newline = true
        state.pending_stacked_newline = true
        state.stacked_indent = next_indent
      end
    end

    -- Apply pending stacked newline to next content token
    ::continue::
    if state.pending_stacked_newline and not token.skip_pending then
      if token.type ~= "whitespace" and token.type ~= "newline" and not is_comma(token) then
        token.newline_before = true
        token.indent_level = state.stacked_indent
        state.pending_stacked_newline = false
      end
    end
    -- Clear skip_pending after processing
    if token.skip_pending then
      token.skip_pending = nil
    end

    -- Apply pending stacked_indent first-item newlines
    -- Skip whitespace, newlines, commas, and parens
    local skip_types = {whitespace=1, newline=1, comma=1, paren_open=1, paren_close=1}
    if not skip_types[token.type] then
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
          token.indent_level = state.base_indent + join_indent + 2
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

    -- GO batch separator - should be on its own line
    if token.type == "go" then
      token.newline_before = true
      token.indent_level = 0
    end

    -- Reset on statement end
    if token.type == "semicolon" or token.type == "go" then
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
  end

  return tokens
end

function StructurePass.info()
  return {
    name = "structure",
    order = 4,
    description = "Determine newlines and indentation for each token",
    annotations = {
      "newline_before", "indent_level", "empty_line_before",
      "is_clause_start", "trailing_newline",
    },
  }
end

return StructurePass
