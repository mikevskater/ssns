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
  ALTER = "alter",
  DROP = "drop",
  TABLE = "table",
  VIEW = "view",
  INDEX = "index",
  INCLUDE = "include",
  PROCEDURE = "procedure",
  FUNCTION = "function",
  RETURNS = "returns",
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
  local in_alter = false  -- Track ALTER statement (distinct from in_create for ALTER TABLE)
  local in_drop = false  -- Track DROP statement (for drop_if_exists_style)
  local drop_saw_object_type = false  -- Track if we've seen TABLE/INDEX/etc after DROP
  local in_create_table = false  -- Track CREATE TABLE statement
  local in_alter_table = false  -- Track ALTER TABLE statement (for alter_table_style)
  local alter_table_saw_table_name = false  -- Track if we've seen the table name after ALTER TABLE
  local in_create_view = false  -- Track CREATE/ALTER VIEW statement (for view_body_indent)
  local in_create_table_columns = false  -- Track inside ( ... ) of CREATE TABLE
  local create_table_paren_depth = 0  -- Track paren depth for CREATE TABLE columns
  local in_create_index = false  -- Track CREATE INDEX statement
  local in_index_columns = false  -- Track inside ( ... ) of CREATE INDEX or inline INDEX
  local index_columns_paren_depth = 0  -- Track paren depth for index columns
  local in_include_clause = false  -- Track INCLUDE ( ... ) clause
  local include_paren_depth = 0  -- Track paren depth for INCLUDE columns
  local in_create_procedure = false  -- Track CREATE PROCEDURE statement
  local in_procedure_params = false  -- Track procedure parameter list (before AS)
  local procedure_params_paren_depth = 0  -- Track paren depth for procedure params (if using parens)
  local in_create_function = false  -- Track CREATE FUNCTION statement
  local in_function_params = false  -- Track function parameter list (before RETURNS)
  local function_params_paren_depth = 0  -- Track paren depth for function params
  local paren_depth = 0
  local select_paren_depth = 0  -- Track paren depth when SELECT started
  local cte_body_paren_depth = nil  -- paren_depth when we entered CTE body (nil = not in CTE body)
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
          in_alter = false
          token.starts_clause = true
        elseif clause_type == "alter" then
          -- ALTER behaves like CREATE for PROCEDURE/FUNCTION/INDEX/TABLE
          in_create = true
          in_alter = true  -- Track that this is ALTER specifically
          token.starts_clause = true
        elseif clause_type == "drop" then
          -- DROP statement tracking for drop_if_exists_style
          in_drop = true
          drop_saw_object_type = false
          token.starts_clause = true
        elseif clause_type == "table" then
          if in_create then
            if in_alter then
              -- ALTER TABLE - track separately for alter_table_style
              in_alter_table = true
              alter_table_saw_table_name = false
            else
              -- CREATE TABLE
              in_create_table = true
            end
          end
        elseif clause_type == "view" then
          -- VIEW keyword in CREATE/ALTER VIEW
          if in_create then
            in_create_view = true
          end
        elseif clause_type == "index" then
          -- INDEX keyword can appear in:
          -- 1. CREATE INDEX ... ON table (columns)
          -- 2. CREATE TABLE ... (... INDEX name (columns) ...)
          -- Both cases should track index columns
          if in_create then
            in_create_index = true
          elseif in_create_table_columns then
            -- Inline INDEX in CREATE TABLE - start tracking for index columns
            in_create_index = true
          end
        elseif clause_type == "include" then
          -- INCLUDE clause in CREATE INDEX
          if in_create_index then
            in_include_clause = true
          end
        elseif clause_type == "procedure" then
          -- PROCEDURE keyword in CREATE/ALTER PROCEDURE
          if in_create then
            in_create_procedure = true
            in_procedure_params = true  -- Parameters start after procedure name
          end
        elseif clause_type == "function" then
          -- FUNCTION keyword in CREATE/ALTER FUNCTION
          if in_create then
            in_create_function = true
            in_function_params = true  -- Parameters start after function name
          end
        elseif clause_type == "returns" then
          -- RETURNS keyword ends function parameters
          if in_create_function then
            in_function_params = false
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

      -- Check for AS in procedure - ends parameter list
      if in_procedure_params and upper == "AS" then
        in_procedure_params = false
      end

      -- Check for AS in VIEW - starts view body
      if in_create_view and upper == "AS" then
        token.is_view_body_as = true
        -- Reset in_create_view since we're now in the view body
        in_create_view = false
        in_create = false
      end

      -- Check for ALTER TABLE action keywords (ADD, DROP, ALTER, NOCHECK, CHECK)
      -- These keywords start a new action in ALTER TABLE and should get newlines in "expanded" style
      if in_alter_table and alter_table_saw_table_name then
        if upper == "ADD" or upper == "DROP" or upper == "ALTER" or
           upper == "NOCHECK" or upper == "CHECK" or upper == "ENABLE" or upper == "DISABLE" then
          token.is_alter_table_action = true
        end
      end

      -- Track DROP statement object types and IF EXISTS
      -- Pattern: DROP TABLE|PROCEDURE|FUNCTION|VIEW|INDEX|TRIGGER|DATABASE|SCHEMA [IF EXISTS] name
      if in_drop then
        -- Object type keywords after DROP
        if not drop_saw_object_type then
          if upper == "TABLE" or upper == "PROCEDURE" or upper == "FUNCTION" or
             upper == "VIEW" or upper == "INDEX" or upper == "TRIGGER" or
             upper == "DATABASE" or upper == "SCHEMA" then
            drop_saw_object_type = true
            token.is_drop_object_type = true
          end
        elseif upper == "IF" then
          -- IF keyword in DROP context - mark it for drop_if_exists_style
          -- Look ahead to confirm it's followed by EXISTS
          for j = i + 1, #tokens do
            local next_tok = tokens[j]
            if next_tok.type == "whitespace" or next_tok.type == "newline" then
              -- Skip whitespace
            elseif next_tok.type == "keyword" and string.upper(next_tok.text) == "EXISTS" then
              token.is_drop_if_exists = true
              break
            else
              break
            end
          end
        end
      end
    end

    -- Track when we've seen the table name after ALTER TABLE
    -- The table name is the identifier(s) immediately after TABLE keyword
    if in_alter_table and not alter_table_saw_table_name then
      if token.type == "identifier" or token.type == "quoted_identifier" then
        -- This is (part of) the table name - we may need to see more (schema.table)
        -- We consider the table name "seen" when we see a keyword that isn't part of the name
      elseif token.type == "keyword" then
        local upper = string.upper(token.text)
        -- These keywords indicate we're past the table name
        if upper == "ADD" or upper == "DROP" or upper == "ALTER" or
           upper == "NOCHECK" or upper == "CHECK" or upper == "ENABLE" or upper == "DISABLE" or
           upper == "WITH" or upper == "SET" or upper == "SWITCH" or upper == "REBUILD" then
          alter_table_saw_table_name = true
          -- Re-mark this keyword as action
          token.is_alter_table_action = true
        end
      elseif token.type ~= "whitespace" and token.type ~= "newline" and token.type ~= "operator" then
        -- For other non-whitespace tokens (except dot operator for schema.table), assume table name is done
        if token.text ~= "." then
          alter_table_saw_table_name = true
        end
      end
    end

    -- Track procedure parameters (with or without parentheses)
    -- Pattern: CREATE PROCEDURE name @p1 INT, @p2 VARCHAR(100) AS ...
    -- Or:      CREATE PROCEDURE name (@p1 INT, @p2 VARCHAR(100)) AS ...
    if in_procedure_params and token.type == "paren_open" then
      if procedure_params_paren_depth == 0 then
        -- This is the opening paren for procedure params (if using parens)
        token.is_procedure_params_open = true
        procedure_params_paren_depth = paren_depth
      end
    elseif in_procedure_params and procedure_params_paren_depth > 0 and token.type == "paren_close" then
      if paren_depth == procedure_params_paren_depth - 1 then
        -- End of procedure params paren
        token.is_procedure_params_close = true
        procedure_params_paren_depth = 0
      end
    end

    -- Mark commas in procedure parameter list
    if in_procedure_params and token.type == "comma" then
      -- If using parens, only mark at the correct depth
      -- If not using parens, mark all commas (they're at paren_depth 0)
      if procedure_params_paren_depth == 0 or paren_depth == procedure_params_paren_depth then
        token.is_procedure_param_separator = true
      end
    end

    -- Track function parameters (always with parentheses)
    -- Pattern: CREATE FUNCTION name (@p1 INT, @p2 VARCHAR(100)) RETURNS ...
    if in_function_params and token.type == "paren_open" then
      if function_params_paren_depth == 0 then
        -- This is the opening paren for function params
        token.is_function_params_open = true
        function_params_paren_depth = paren_depth
      end
    elseif in_function_params and function_params_paren_depth > 0 and token.type == "paren_close" then
      if paren_depth == function_params_paren_depth - 1 then
        -- End of function params paren
        token.is_function_params_close = true
        function_params_paren_depth = 0
        in_function_params = false  -- Params end at closing paren
      end
    end

    -- Mark commas in function parameter list
    if in_function_params and function_params_paren_depth > 0 and token.type == "comma" then
      if paren_depth == function_params_paren_depth then
        token.is_function_param_separator = true
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
        -- Remember the paren depth when we entered CTE body (paren_depth was already incremented above)
        cte_body_paren_depth = paren_depth
      else
        -- This is the CTE columns paren (before AS)
        token.is_cte_columns_open = true
        in_cte_columns = true
      end
    elseif in_cte_columns and token.type == "paren_close" then
      -- End of CTE column list
      token.is_cte_columns_close = true
      in_cte_columns = false
    elseif in_cte and cte_body_paren_depth and token.type == "paren_close" and paren_depth < cte_body_paren_depth then
      -- We're closing the CTE body paren (paren_depth was already decremented above)
      -- paren_depth is now less than cte_body_paren_depth means we've closed the CTE paren
      token.is_cte_close_paren = true
      cte_body_paren_depth = nil  -- No longer in CTE body
    end

    -- Mark commas inside CTE column list
    if in_cte_columns and token.type == "comma" then
      token.is_cte_column_separator = true
    end

    -- Comma after CTE definition starts a new CTE
    -- cte_body_paren_depth == nil means we're not inside a CTE body
    if in_cte and cte_body_paren_depth == nil and not in_cte_columns and token.type == "comma" then
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

    -- Mark commas that separate ALTER TABLE operations (at paren depth 0)
    -- Pattern: ALTER TABLE t ADD col1 INT, ADD col2 VARCHAR(100)
    if in_alter_table and alter_table_saw_table_name and token.type == "comma" and paren_depth == 0 then
      token.is_alter_table_separator = true
    end

    -- Track CREATE INDEX column definitions paren
    -- Pattern: CREATE INDEX name ON table (col1, col2, ...) or INDEX name (col1, col2) in CREATE TABLE
    if in_create_index and token.type == "paren_open" then
      if in_include_clause then
        -- This is the opening paren for INCLUDE columns
        if include_paren_depth == 0 then
          token.is_index_include_open = true
          include_paren_depth = paren_depth
        end
      elseif not in_index_columns then
        -- This is the opening paren for index key columns
        token.is_index_columns_open = true
        in_index_columns = true
        index_columns_paren_depth = paren_depth
      end
    elseif in_index_columns and token.type == "paren_close" then
      if paren_depth == index_columns_paren_depth - 1 then
        -- End of index key columns
        token.is_index_columns_close = true
        in_index_columns = false
        -- Don't reset in_create_index yet - there might be INCLUDE or WHERE clause
      end
    elseif in_include_clause and include_paren_depth > 0 and token.type == "paren_close" then
      if paren_depth == include_paren_depth - 1 then
        -- End of INCLUDE columns
        token.is_index_include_close = true
        in_include_clause = false
        include_paren_depth = 0
      end
    end

    -- Mark commas inside index column list (at the top level only)
    if in_index_columns and token.type == "comma" and paren_depth == index_columns_paren_depth then
      token.is_index_column_separator = true
    end

    -- Mark commas inside INCLUDE column list
    if in_include_clause and include_paren_depth > 0 and token.type == "comma" and paren_depth == include_paren_depth then
      token.is_index_include_separator = true
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
    token.in_cte_body = in_cte and cte_body_paren_depth ~= nil  -- True only inside CTE subquery body
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
      in_alter = false
      in_drop = false
      drop_saw_object_type = false
      in_create_table = false
      in_alter_table = false
      alter_table_saw_table_name = false
      in_create_view = false
      in_create_table_columns = false
      create_table_paren_depth = 0
      in_create_index = false
      in_index_columns = false
      index_columns_paren_depth = 0
      in_include_clause = false
      include_paren_depth = 0
      in_create_procedure = false
      in_procedure_params = false
      procedure_params_paren_depth = 0
      in_create_function = false
      in_function_params = false
      function_params_paren_depth = 0
      paren_depth = 0
      cte_body_paren_depth = nil
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
