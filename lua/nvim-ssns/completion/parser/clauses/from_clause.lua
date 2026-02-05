--- FROM clause parser module
--- Parses FROM/JOIN clauses to extract table references and subqueries
---
--- Handles:
--- - Simple table references (FROM dbo.Table)
--- - JOINs (INNER, LEFT, RIGHT, FULL, CROSS)
--- - Subqueries in FROM clause (FROM (SELECT ...) AS alias)
--- - VALUES table constructor (FROM (VALUES ...) AS alias)
--- - CROSS/OUTER APPLY with TVFs and subqueries
--- - Table hints (WITH NOLOCK)
---
---@module ssns.completion.parser.clauses.from_clause

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')
local QualifiedName = require('nvim-ssns.completion.parser.utils.qualified_name')
local AliasParser = require('nvim-ssns.completion.parser.utils.alias')
local TableReferenceParser = require('nvim-ssns.completion.parser.utils.table_reference')
local ValuesClauseParser = require('nvim-ssns.completion.parser.clauses.values_clause')

local FromClauseParser = {}

---@class FromClauseResult
---@field tables TableReference[] Tables from FROM/JOIN
---@field clause_position ClausePosition? Position of the FROM clause
---@field join_positions ClausePosition[] Positions of each JOIN clause
---@field on_positions ClausePosition[] Positions of each ON clause

---Parse FROM/JOIN clauses to extract tables
---
---@param state ParserState Token navigation state
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param from_start_token table? The FROM keyword token (for position tracking)
---@return FromClauseResult result The parsed FROM clause result
function FromClauseParser.parse(state, scope, from_start_token)
  local tables = {}
  local paren_depth = 0

  -- Track FROM clause position
  local clause_pos = nil
  if from_start_token then
    clause_pos = {
      start_line = from_start_token.line,
      start_col = from_start_token.col,
      end_line = from_start_token.line,
      end_col = from_start_token.col,
    }
  end

  -- Track individual JOIN and ON positions
  local join_positions = {}
  local on_positions = {}
  local current_join_start = nil
  local current_on_start = nil
  local join_count = 0

  -- Build known_ctes table for compatibility with parse_subquery/parse_table_reference
  local known_ctes = scope and scope:get_known_ctes_table() or {}

  while state:current() do
    local token = state:current()

    -- Handle parens
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      state:advance()

      -- Check for subquery or VALUES table constructor
      if state:is_keyword("SELECT") then
        -- Parse the subquery
        local subquery = state:parse_subquery(known_ctes)
        if subquery then
          -- Find closing paren and alias
          if state:is_type("paren_close") then
            paren_depth = paren_depth - 1
            state:advance()
            subquery.alias = AliasParser.parse(state)
          end
          -- Add to scope
          if scope then
            scope:add_subquery(subquery)
          end
        end
        -- Continue parsing FROM clause (may have more tables/subqueries)
      elseif state:is_keyword("VALUES") then
        -- Parse VALUES table constructor using shared parser
        local values_subquery = ValuesClauseParser.parse_table_constructor(state, token)
        if values_subquery then
          paren_depth = paren_depth - 1  -- parse_table_constructor consumes closing paren
          if scope then
            scope:add_subquery(values_subquery)
          end
        end
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      state:advance()
    elseif Keywords.is_from_keyword(token.text) then
      local upper_text = token.text:upper()

      -- Track JOIN/ON positions
      if upper_text ~= "FROM" then
        -- End previous ON clause if any
        if current_on_start then
          local prev_token = state.tokens[state.pos - 1]
          if prev_token then
            table.insert(on_positions, {
              start_line = current_on_start.line,
              start_col = current_on_start.col,
              end_line = prev_token.line,
              end_col = prev_token.col + #prev_token.text - 1,
            })
          end
          current_on_start = nil
        end

        -- Track new JOIN start
        if upper_text ~= "JOIN" and Keywords.JOIN_MODIFIERS[upper_text] then
          current_join_start = token
        elseif upper_text == "JOIN" then
          current_join_start = token
          join_count = join_count + 1
        end
      end

      state:advance()

      -- Skip JOIN modifiers
      while state:current() and Keywords.JOIN_MODIFIERS[state:current().text:upper()] do
        state:advance()
      end

      -- Skip the JOIN keyword itself (if present after modifiers)
      if state:is_keyword("JOIN") then
        if not current_join_start then
          current_join_start = state:current()
        end
        join_count = join_count + 1
        state:advance()
      end

      -- Handle APPLY (CROSS APPLY, OUTER APPLY) - T-SQL specific
      if state:is_keyword("APPLY") then
        FromClauseParser._parse_apply(state, tables, scope, known_ctes)
        goto continue_from_loop
      end

      -- Check for ON keyword before table reference
      if state:is_keyword("ON") then
        -- End the current JOIN position
        if current_join_start then
          local prev_token = state.tokens[state.pos - 1]
          if prev_token then
            table.insert(join_positions, {
              start_line = current_join_start.line,
              start_col = current_join_start.col,
              end_line = prev_token.line,
              end_col = prev_token.col + #prev_token.text - 1,
            })
          end
          current_join_start = nil
        end

        -- Start tracking ON clause
        current_on_start = state:current()
        state:advance()
        goto continue_from_loop
      end

      -- Parse table reference
      local table_ref = TableReferenceParser.parse(state, scope)
      if table_ref then
        table.insert(tables, table_ref)
      end

      -- Handle comma-separated tables (FROM A, B, C)
      while state:is_type("comma") do
        state:advance()
        table_ref = TableReferenceParser.parse(state, scope)
        if table_ref then
          table.insert(tables, table_ref)
        end
      end

      ::continue_from_loop::
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      -- GO batch separator - stop parsing FROM clause
      break
    elseif paren_depth == 0 and Keywords.is_statement_starter(token.text) then
      -- New statement starting
      -- BUT: WITH in FROM clause context is a table hint, not a CTE starter
      if token.text:upper() == "WITH" then
        FromClauseParser._skip_table_hint(state)
      else
        break
      end
    elseif paren_depth == 0 and (token.text:upper() == "UNION" or token.text:upper() == "INTERSECT" or token.text:upper() == "EXCEPT") then
      -- Set operations - stop parsing FROM clause
      break
    elseif paren_depth == 0 and token.type == "keyword" and Keywords.FROM_TERMINATORS[token.text:upper()] then
      -- FROM clause terminators (WHERE, GROUP BY, ORDER BY, etc.)
      break
    elseif paren_depth == 0 and state:is_keyword("ON") then
      -- ON keyword after table reference
      -- End any current JOIN position
      if current_join_start then
        local prev_token = state.tokens[state.pos - 1]
        if prev_token then
          table.insert(join_positions, {
            start_line = current_join_start.line,
            start_col = current_join_start.col,
            end_line = prev_token.line,
            end_col = prev_token.col + #prev_token.text - 1,
          })
        end
        current_join_start = nil
      end

      -- End previous ON clause if any
      if current_on_start then
        local prev_token = state.tokens[state.pos - 1]
        if prev_token then
          table.insert(on_positions, {
            start_line = current_on_start.line,
            start_col = current_on_start.col,
            end_line = prev_token.line,
            end_col = prev_token.col + #prev_token.text - 1,
          })
        end
      end

      -- Start tracking new ON clause
      current_on_start = state:current()
      state:advance()
    else
      state:advance()
    end
  end

  -- Update clause end position
  if clause_pos then
    local last_token = state.pos > 1 and state.tokens[state.pos - 1] or from_start_token
    if last_token then
      clause_pos.end_line = last_token.line
      clause_pos.end_col = last_token.col + #last_token.text - 1
    end
  end

  -- Finalize any open JOIN clause
  if current_join_start then
    local end_token = state.tokens[state.pos - 1] or current_join_start
    table.insert(join_positions, {
      start_line = current_join_start.line,
      start_col = current_join_start.col,
      end_line = end_token.line,
      end_col = end_token.col + #end_token.text - 1,
    })
  end

  -- Finalize any open ON clause
  if current_on_start then
    local end_token = state.tokens[state.pos - 1] or current_on_start
    table.insert(on_positions, {
      start_line = current_on_start.line,
      start_col = current_on_start.col,
      end_line = end_token.line,
      end_col = end_token.col + #end_token.text - 1,
    })
  end

  return {
    tables = tables,
    clause_position = clause_pos,
    join_positions = join_positions,
    on_positions = on_positions,
  }
end

---Parse CROSS/OUTER APPLY
---@param state ParserState
---@param tables TableReference[] Tables collection to add to
---@param scope ScopeContext? Scope context
---@param known_ctes table<string, boolean> Known CTEs
---@private
function FromClauseParser._parse_apply(state, tables, scope, known_ctes)
  state:advance()  -- consume APPLY

  -- Check for subquery: CROSS APPLY (SELECT ...)
  if state:is_type("paren_open") then
    state:advance()  -- consume (
    if state:is_keyword("SELECT") then
      -- Parse as subquery
      local subquery = state:parse_subquery(known_ctes)
      if subquery then
        -- parse_subquery stops AT the closing ) - consume it
        if state:is_type("paren_close") then
          state:advance()
        end
        -- Parse the alias BEFORE adding to subqueries
        local apply_alias = AliasParser.parse(state)
        if apply_alias then
          subquery.alias = apply_alias
        end
        if scope then
          scope:add_subquery(subquery)
        end
      end
    else
      -- Skip parenthesized function call or VALUES (already inside parens)
      local paren_depth = 1
      while state:current() and paren_depth > 0 do
        if state:is_type("paren_open") then
          paren_depth = paren_depth + 1
        elseif state:is_type("paren_close") then
          paren_depth = paren_depth - 1
        end
        state:advance()
      end
      -- Skip optional alias
      AliasParser.parse(state)
    end
  else
    -- Table-valued function without subquery: CROSS APPLY dbo.GetOrders(e.Id) AS o
    local tvf_qualified = QualifiedName.parse(state)
    -- Skip function arguments if present
    if state:is_type("paren_open") then
      state:skip_paren_contents()
    end
    -- Parse alias for table-valued function
    local tvf_alias = AliasParser.parse(state)
    -- Track TVF as a table reference
    if tvf_qualified then
      local tvf_ref = {
        name = tvf_qualified.name,
        schema = tvf_qualified.schema or "dbo",
        database = tvf_qualified.database,
        alias = tvf_alias or tvf_qualified.name,
        is_tvf = true,
        function_name = tvf_qualified.name,
      }
      table.insert(tables, tvf_ref)
    end
  end
end

---Skip table hint (WITH NOLOCK, etc.)
---@param state ParserState
---@private
function FromClauseParser._skip_table_hint(state)
  state:advance()  -- consume WITH
  if state:is_type("paren_open") then
    -- Skip parenthesized hints like (NOLOCK, INDEX(...))
    state:skip_paren_contents()
  end
end

return FromClauseParser
