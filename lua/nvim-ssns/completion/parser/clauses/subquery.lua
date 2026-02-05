---Subquery parsing module
---Handles parsing of nested SELECT subqueries within parentheses
---@class SubqueryParser

local ScopeContext = require('nvim-ssns.completion.parser.scope')
local SelectListParser = require('nvim-ssns.completion.parser.clauses.select_list')
local FromClauseParser = require('nvim-ssns.completion.parser.clauses.from_clause')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

local SubqueryParser = {}

---Parse a subquery recursively
---@param state ParserState Parser state positioned at SELECT keyword
---@param known_ctes table<string, boolean> Known CTE names
---@return SubqueryInfo?
function SubqueryParser.parse(state, known_ctes)
  local start_token = state:current()
  if not start_token then
    return nil
  end

  -- Track token range for parameter extraction
  local start_token_idx = state.pos

  local subquery = {
    alias = nil,
    columns = {},
    tables = {},
    subqueries = {},
    parameters = {},
    start_pos = { line = start_token.line, col = start_token.col },
    end_pos = { line = start_token.line, col = start_token.col },
    clause_positions = {},
  }

  -- Create a temporary scope for this subquery
  local scope = ScopeContext.new(nil)
  -- Populate scope.ctes from known_ctes
  for name, _ in pairs(known_ctes or {}) do
    scope:add_cte(name, { name = name, columns = {}, tables = {}, subqueries = {}, parameters = {} })
  end

  -- We're at SELECT keyword - save it for position tracking
  local select_token = state:current()
  state:advance()

  -- Parse SELECT list using the SelectListParser module
  local select_clause_pos
  subquery.columns, select_clause_pos = SelectListParser.parse(state, scope, select_token)
  if select_clause_pos then
    subquery.clause_positions["select"] = select_clause_pos
  end

  -- Parse FROM clause using the FromClauseParser module
  if state:is_keyword("FROM") then
    local from_token = state:current()
    local result = FromClauseParser.parse(state, scope, from_token)
    subquery.tables = result.tables
    if result.clause_position then
      subquery.clause_positions["from"] = result.clause_position
    end
    -- Add join and on positions
    if result.join_positions then
      for i, pos in ipairs(result.join_positions) do
        subquery.clause_positions["join_" .. i] = pos
      end
    end
    if result.on_positions then
      for i, pos in ipairs(result.on_positions) do
        subquery.clause_positions["on_" .. i] = pos
      end
    end
  end

  -- Copy subqueries from scope
  subquery.subqueries = scope.subqueries

  -- Handle set operations (UNION, INTERSECT, EXCEPT) to capture tables from all members
  local where_start = nil
  local last_token_before_end = nil

  while state:current() do
    -- Skip until we hit UNION/INTERSECT/EXCEPT or end of subquery
    local set_op_paren_depth = 0
    while state:current() do
      local token = state:current()

      -- Track WHERE clause start
      if set_op_paren_depth == 0 and state:is_keyword("WHERE") and not where_start then
        where_start = token
      end

      -- Track last token for WHERE clause end position
      last_token_before_end = token

      if token.type == "paren_open" then
        set_op_paren_depth = set_op_paren_depth + 1
        state:advance()
        -- Check for nested subquery: (SELECT ...
        if state:is_keyword("SELECT") then
          local nested = SubqueryParser.parse(state, known_ctes)
          if nested then
            table.insert(subquery.subqueries, nested)
          end
          -- After parse, parser is AT the closing ) - consume it
          if state:is_type("paren_close") then
            last_token_before_end = state:current()
            state:advance()
          end
          set_op_paren_depth = set_op_paren_depth - 1
        end
      elseif token.type == "paren_close" then
        if set_op_paren_depth == 0 then
          -- End of subquery - record WHERE clause position
          if where_start and last_token_before_end then
            subquery.clause_positions["where"] = {
              start_line = where_start.line,
              start_col = where_start.col,
              end_line = last_token_before_end.line,
              end_col = last_token_before_end.col + #last_token_before_end.text - 1,
            }
          end
          break
        end
        set_op_paren_depth = set_op_paren_depth - 1
        state:advance()
      elseif set_op_paren_depth == 0 and (state:is_keyword("UNION") or state:is_keyword("INTERSECT") or state:is_keyword("EXCEPT")) then
        -- Found set operation - record WHERE clause position
        if where_start and last_token_before_end then
          subquery.clause_positions["where"] = {
            start_line = where_start.line,
            start_col = where_start.col,
            end_line = last_token_before_end.line,
            end_col = last_token_before_end.col + #last_token_before_end.text - 1,
          }
        end
        break
      else
        state:advance()
      end
    end

    local is_set_op = state:is_keyword("UNION") or state:is_keyword("INTERSECT") or state:is_keyword("EXCEPT")
    if not is_set_op then
      break
    end

    state:advance()  -- consume UNION/INTERSECT/EXCEPT

    -- Handle ALL or DISTINCT modifier
    if state:is_keyword("ALL") or state:is_keyword("DISTINCT") then
      state:advance()
    end

    -- Expect SELECT
    if not state:is_keyword("SELECT") then
      break
    end
    state:advance()  -- consume SELECT

    -- Skip SELECT list until FROM
    local select_paren_depth = 0
    while state:current() do
      if state:is_type("paren_open") then
        select_paren_depth = select_paren_depth + 1
      elseif state:is_type("paren_close") then
        if select_paren_depth > 0 then
          select_paren_depth = select_paren_depth - 1
        else
          break  -- End of subquery
        end
      elseif select_paren_depth == 0 and state:is_keyword("FROM") then
        break  -- Found FROM clause
      end
      state:advance()
    end

    -- Parse FROM clause for UNION member
    if state:is_keyword("FROM") then
      local from_token = state:current()
      local union_scope = ScopeContext.new(nil)
      for name, _ in pairs(known_ctes or {}) do
        union_scope:add_cte(name, { name = name, columns = {}, tables = {}, subqueries = {}, parameters = {} })
      end
      local result = FromClauseParser.parse(state, union_scope, from_token)
      for _, tbl in ipairs(result.tables) do
        table.insert(subquery.tables, tbl)
      end
    end
  end

  -- Parse remaining nested subqueries
  local scan_depth = 0
  while state:current() do
    if state:is_type("paren_open") then
      scan_depth = scan_depth + 1
      state:advance()
      if state:is_keyword("SELECT") then
        local nested = SubqueryParser.parse(state, known_ctes)
        if nested then
          table.insert(subquery.subqueries, nested)
        end
        scan_depth = scan_depth - 1
      end
    elseif state:is_type("paren_close") then
      if scan_depth <= 0 then
        break  -- End of current subquery
      end
      scan_depth = scan_depth - 1
      state:advance()
    else
      state:advance()
    end
  end

  -- Record end position
  local end_token = state:current()
  if end_token then
    subquery.end_pos = { line = end_token.line, col = end_token.col }
  end

  -- Build alias mapping for this subquery
  local subquery_aliases = {}
  for _, table_ref in ipairs(subquery.tables) do
    if table_ref.alias then
      subquery_aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Resolve parent_table for columns
  Helpers.resolve_column_parents(subquery.columns, subquery_aliases, subquery.tables)

  -- Extract parameters from tokens
  local end_token_idx = state.pos - 1
  if end_token_idx >= start_token_idx then
    state:extract_all_parameters_from_tokens(start_token_idx, end_token_idx, subquery.parameters)
  end

  return subquery
end

return SubqueryParser
