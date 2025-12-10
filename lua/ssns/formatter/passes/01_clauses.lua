---@class ClausesPass
---Pass 1: Mark clause boundaries and track clause context
---
---This pass annotates tokens with clause information:
---  token.clause_type      - "select", "from", "where", "group_by", "order_by", "having", etc.
---  token.starts_clause    - true if this token starts a clause
---  token.in_select_list   - true if inside SELECT column list
---  token.in_from_clause   - true if inside FROM clause
---  token.in_where_clause  - true if inside WHERE clause
---  token.in_group_by      - true if inside GROUP BY
---  token.in_order_by      - true if inside ORDER BY
---  token.in_having        - true if inside HAVING
---  token.in_join_clause   - true if inside JOIN...ON
---  token.in_on_clause     - true if inside ON condition
---  token.in_set_clause    - true if inside UPDATE SET
---  token.in_values_clause - true if inside VALUES
---  token.in_cte           - true if inside CTE definition
---  token.in_insert_columns - true if inside INSERT column list
---  token.in_merge         - true if inside MERGE statement
local ClausesPass = {}

-- Major SQL clauses
local MAJOR_CLAUSES = {
  SELECT = "select",
  FROM = "from",
  WHERE = "where",
  ["GROUP"] = "group_by",
  ["ORDER"] = "order_by",
  HAVING = "having",
  JOIN = "join",
  ON = "on",
  SET = "set",
  VALUES = "values",
  INSERT = "insert",
  UPDATE = "update",
  DELETE = "delete",
  MERGE = "merge",
  USING = "using",
  WHEN = "when",
  WITH = "with",
  UNION = "union",
  INTERSECT = "intersect",
  EXCEPT = "except",
  OUTPUT = "output",
  CREATE = "create",
  TABLE = "table",
}

-- Join modifiers
local JOIN_MODIFIERS = {
  INNER = true, LEFT = true, RIGHT = true, FULL = true,
  OUTER = true, CROSS = true, NATURAL = true,
}

---Run the clauses pass
---@param tokens table[] Array of tokens
---@param config table Formatter configuration
---@return table[] Annotated tokens
function ClausesPass.run(tokens, config)
  config = config or {}

  -- State tracking
  local current_clause = nil
  local in_select_list = false
  local in_from_clause = false
  local in_where_clause = false
  local in_group_by = false
  local in_order_by = false
  local in_having = false
  local in_join_clause = false
  local in_on_clause = false
  local in_set_clause = false
  local in_values_clause = false
  local in_cte = false
  local in_insert_columns = false
  local in_merge = false
  local in_update = false
  local in_delete = false
  local in_create = false  -- Track CREATE statement
  local in_create_table = false  -- Track CREATE TABLE statement
  local in_create_table_columns = false  -- Track inside ( ... ) of CREATE TABLE
  local create_table_paren_depth = 0  -- Track paren depth for CREATE TABLE columns
  local paren_depth = 0
  local select_paren_depth = 0  -- Track paren depth when SELECT started
  local cte_paren_depth = 0  -- Track when we enter CTE subquery
  local in_cte_definition = false  -- True between WITH and AS (
  local saw_cte_as = false  -- Track when we've seen AS in CTE definition
  local in_cte_columns = false  -- True when inside CTE column list: cte(col1, col2)

  for i, token in ipairs(tokens) do
    -- Track parenthesis depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then paren_depth = 0 end
    end

    -- Default annotations
    token.starts_clause = false
    token.clause_type = current_clause

    -- Check for clause keywords
    if token.type == "keyword" then
      local upper = string.upper(token.text)

      -- FIRST: Check for table hint WITH (NOLOCK, ROWLOCK, etc.)
      -- Table hint WITH appears in FROM/JOIN clause, followed by (
      -- This must be checked BEFORE clause_type handling to avoid
      -- treating table hint WITH as CTE WITH
      local is_table_hint_with = false
      if upper == "WITH" and in_from_clause then
        -- Look ahead for paren_open to confirm it's a table hint
        for j = i + 1, #tokens do
          local next_tok = tokens[j]
          if next_tok.type == "whitespace" or next_tok.type == "newline" then
            -- Skip whitespace (though tokenizer usually strips these)
          elseif next_tok.type == "paren_open" then
            -- It's a table hint: WITH (NOLOCK)
            is_table_hint_with = true
            token.is_table_hint_with = true
            break
          else
            -- Not followed by (, not a table hint
            break
          end
        end
      end

      local clause_type = MAJOR_CLAUSES[upper]

      if clause_type then
        -- Reset previous clause flags
        if clause_type == "select" then
          in_select_list = true
          in_from_clause = false
          in_where_clause = false
          in_group_by = false
          in_order_by = false
          in_having = false
          in_on_clause = false
          select_paren_depth = paren_depth
          token.starts_clause = true
        elseif clause_type == "from" then
          in_select_list = false
          in_from_clause = true
          in_where_clause = false
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "where" then
          in_select_list = false
          in_from_clause = false
          in_where_clause = true
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "group_by" then
          in_select_list = false
          in_from_clause = false
          in_where_clause = false
          in_group_by = true
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "order_by" then
          in_select_list = false
          in_from_clause = false
          in_where_clause = false
          in_group_by = false
          in_order_by = true
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "having" then
          in_select_list = false
          in_from_clause = false
          in_where_clause = false
          in_having = true
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "join" then
          in_join_clause = true
          in_on_clause = false
          token.starts_clause = true
        elseif clause_type == "on" then
          in_on_clause = true
          token.starts_clause = true
        elseif clause_type == "set" then
          in_set_clause = true
          in_select_list = false
          in_from_clause = false
          token.starts_clause = true
        elseif clause_type == "values" then
          in_values_clause = true
          in_insert_columns = false
          token.starts_clause = true
        elseif clause_type == "insert" then
          in_insert_columns = true
          token.starts_clause = true
        elseif clause_type == "update" then
          in_update = true
          token.starts_clause = true
        elseif clause_type == "delete" then
          in_delete = true
          token.starts_clause = true
        elseif clause_type == "merge" then
          in_merge = true
          token.starts_clause = true
        elseif clause_type == "with" and not is_table_hint_with then
          -- Only treat as CTE if NOT a table hint WITH (NOLOCK)
          in_cte = true
          in_cte_definition = true  -- Waiting for AS and (
          token.starts_clause = true
        elseif clause_type == "union" or clause_type == "intersect" or clause_type == "except" then
          -- Reset for next statement
          in_select_list = false
          in_from_clause = false
          in_where_clause = false
          in_group_by = false
          in_order_by = false
          token.starts_clause = true
        elseif clause_type == "create" then
          in_create = true
          token.starts_clause = true
        elseif clause_type == "table" then
          if in_create then
            in_create_table = true
          end
        end

        current_clause = clause_type
        token.clause_type = clause_type
      end

      -- Check for join modifiers
      if JOIN_MODIFIERS[upper] then
        token.is_join_modifier = true
        in_join_clause = true
      end

      -- Check for AS in CTE definition
      if in_cte_definition and upper == "AS" then
        token.is_cte_as = true
        saw_cte_as = true
        in_cte_columns = false  -- End of column list
      end
    end

    -- Track CTE columns paren (before AS) vs CTE subquery paren (after AS)
    -- Pattern: WITH cte (columns) AS (subquery)
    --          ^^^^^^^^^^^^^^^^^--- in_cte_definition, in_cte_columns
    --                              ^^^^^^^^^^^^---- is_cte_open_paren (subquery)
    if in_cte_definition and token.type == "paren_open" then
      if saw_cte_as then
        -- This is the subquery paren after AS
        token.is_cte_open_paren = true
        in_cte_definition = false  -- Now inside CTE subquery
        saw_cte_as = false
        cte_paren_depth = cte_paren_depth + 1
      else
        -- This is the CTE columns paren (before AS)
        token.is_cte_columns_open = true
        in_cte_columns = true
      end
    elseif in_cte_columns and token.type == "paren_close" then
      -- End of CTE column list
      token.is_cte_columns_close = true
      in_cte_columns = false
    elseif in_cte and cte_paren_depth > 0 and token.type == "paren_close" then
      cte_paren_depth = cte_paren_depth - 1
      if cte_paren_depth == 0 then
        -- End of CTE subquery, check for comma (more CTEs) or SELECT
        -- Will be handled by next token
        token.is_cte_close_paren = true
      end
    end

    -- Mark commas inside CTE column list
    if in_cte_columns and token.type == "comma" then
      token.is_cte_column_separator = true
    end

    -- Comma after CTE definition starts a new CTE
    if in_cte and cte_paren_depth == 0 and not in_cte_columns and token.type == "comma" then
      in_cte_definition = true  -- Ready for next CTE name and AS
      saw_cte_as = false
    end

    -- Track CREATE TABLE column definitions paren
    -- Pattern: CREATE TABLE tablename (col1 INT, col2 VARCHAR(100), ...)
    if in_create_table and token.type == "paren_open" then
      if not in_create_table_columns then
        -- This is the opening paren for column definitions
        token.is_create_table_columns_open = true
        in_create_table_columns = true
        create_table_paren_depth = paren_depth
      end
    elseif in_create_table_columns and token.type == "paren_close" then
      -- paren_depth was already decremented at the top of the loop
      -- So we need to check if we're one level below the stored depth
      -- (i.e., this close paren brings us back to before the CREATE TABLE columns)
      if paren_depth == create_table_paren_depth - 1 then
        -- End of CREATE TABLE column definitions
        token.is_create_table_columns_close = true
        in_create_table_columns = false
        in_create_table = false
        in_create = false
      end
    end

    -- Mark commas inside CREATE TABLE column definitions (at the top level only)
    -- Exclude commas inside nested parens like VARCHAR(10, 2) or DECIMAL(18, 2)
    if in_create_table_columns and token.type == "comma" and paren_depth == create_table_paren_depth then
      token.is_create_table_column_separator = true
    end

    -- Mark table-level constraints in CREATE TABLE for create_table_constraint_newline
    -- These are: CONSTRAINT keyword, or PRIMARY KEY/FOREIGN KEY/UNIQUE/CHECK/INDEX at table level
    -- Table-level means: appears after a comma at the top paren level (not inline with column def)
    if in_create_table_columns and token.type == "keyword" and paren_depth == create_table_paren_depth then
      local upper = string.upper(token.text)
      -- CONSTRAINT keyword is always a table-level constraint definition
      if upper == "CONSTRAINT" then
        token.is_table_constraint_start = true
      -- PRIMARY, FOREIGN, UNIQUE, CHECK, INDEX at table level (after comma, not following column type)
      -- We check if this is after a comma by looking back for the comma
      elseif upper == "PRIMARY" or upper == "FOREIGN" or upper == "UNIQUE" or upper == "CHECK" or upper == "INDEX" then
        -- Look back to find what precedes this keyword
        -- If it's a comma (at this paren level), it's a table-level constraint
        for j = i - 1, 1, -1 do
          local prev_tok = tokens[j]
          if prev_tok.type == "whitespace" or prev_tok.type == "newline" then
            -- Skip whitespace
          elseif prev_tok.type == "comma" then
            -- Table-level constraint (after comma)
            token.is_table_constraint_start = true
            break
          else
            -- Something else precedes (like column name/type) - inline constraint
            break
          end
        end
      end
    end

    -- Mark commas that separate value rows in INSERT ... VALUES (...), (...), (...)
    -- These are commas outside all parentheses while in VALUES clause
    if in_values_clause and token.type == "comma" and paren_depth == 0 then
      token.is_values_row_separator = true
    end

    -- Apply clause context to token
    token.in_select_list = in_select_list
    token.in_from_clause = in_from_clause
    token.in_where_clause = in_where_clause
    token.in_group_by = in_group_by
    token.in_order_by = in_order_by
    token.in_having = in_having
    token.in_join_clause = in_join_clause
    token.in_on_clause = in_on_clause
    token.in_set_clause = in_set_clause
    token.in_values_clause = in_values_clause
    token.in_cte = in_cte
    token.in_insert_columns = in_insert_columns
    token.in_merge = in_merge
    token.in_update = in_update
    token.in_delete = in_delete
    token.in_create_table_columns = in_create_table_columns

    -- End clauses on semicolon or GO
    if token.type == "semicolon" or token.type == "go" then
      current_clause = nil
      in_select_list = false
      in_from_clause = false
      in_where_clause = false
      in_group_by = false
      in_order_by = false
      in_having = false
      in_join_clause = false
      in_on_clause = false
      in_set_clause = false
      in_values_clause = false
      in_cte = false
      in_insert_columns = false
      in_merge = false
      in_update = false
      in_delete = false
      in_create = false
      in_create_table = false
      in_create_table_columns = false
      create_table_paren_depth = 0
      paren_depth = 0
      cte_paren_depth = 0
      in_cte_definition = false
      saw_cte_as = false
      in_cte_columns = false
    end
  end

  return tokens
end

---Get pass information
---@return table Pass metadata
function ClausesPass.info()
  return {
    name = "clauses",
    order = 1,
    description = "Mark clause boundaries and track clause context",
    annotations = {
      "clause_type", "starts_clause",
      "in_select_list", "in_from_clause", "in_where_clause",
      "in_group_by", "in_order_by", "in_having",
      "in_join_clause", "in_on_clause", "in_set_clause",
      "in_values_clause", "in_cte", "in_insert_columns",
      "in_merge", "in_update", "in_delete",
    },
  }
end

return ClausesPass
