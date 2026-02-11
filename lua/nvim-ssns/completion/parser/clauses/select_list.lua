--- SELECT list parser module
--- Parses the column list in a SELECT statement
---
--- Extracts columns, handles aliases, and identifies subqueries in the SELECT list.
---
---@module ssns.completion.parser.clauses.select_list

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

local SelectListParser = {}

---Parse the SELECT list (columns between SELECT and FROM/INTO)
---
---@param state ParserState Token navigation state
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param select_start_token table? The SELECT keyword token (for position tracking)
---@return ColumnInfo[] columns The parsed columns
---@return ClausePosition? clause_pos Position of the SELECT clause
function SelectListParser.parse(state, scope, select_start_token)
  local columns = {}
  local current_col = nil
  local current_source_table = nil
  local current_expr_cols = {}  -- Tracks qualified table.column refs within current expression
  local paren_depth = 0

  -- Track SELECT clause position
  local clause_pos = nil
  if select_start_token then
    clause_pos = {
      start_line = select_start_token.line,
      start_col = select_start_token.col,
      end_line = select_start_token.line,
      end_col = select_start_token.col,
    }
  end

  while state:current() do
    local token = state:current()

    -- Stop at FROM or INTO keyword at same paren depth
    -- INTO is needed for SELECT...INTO table patterns
    if paren_depth == 0 and (state:is_keyword("FROM") or state:is_keyword("INTO")) then
      break
    end

    -- Handle nested parens
    if token.type == "paren_open" then
      -- Check for subquery: (SELECT ...)
      local next_pos = state.pos + 1
      local next_token = state.tokens[next_pos]
      if next_token and next_token.type == "keyword" and next_token.text:upper() == "SELECT" then
        -- This is a subquery in SELECT list
        state:advance()  -- consume (
        if scope then
          -- parse_subquery is still on ParserState
          local known_ctes = scope:get_known_ctes_table()
          local subquery = state:parse_subquery(known_ctes)
          if subquery then
            scope:add_subquery(subquery)
            -- Expect closing paren
            if state:is_type("paren_close") then
              state:advance()  -- consume )
            end
          end
        else
          -- Skip if no scope provided
          state:skip_paren_contents()
        end
      else
        -- Regular parenthesized expression
        paren_depth = paren_depth + 1
        state:advance()
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      state:advance()
    elseif token.type == "star" then
      -- Check context: is this SELECT * or arithmetic *?
      if current_col and paren_depth == 0 then
        -- Arithmetic operator at column level (e.g., "Salary * 12")
        -- Skip the * and continue - the expression result will be
        -- captured when we hit AS (alias) or comma/FROM (no alias)
        state:advance()
        -- Continue consuming the expression until AS, comma, or FROM
        while state:current() do
          local next_tok = state:current()
          if not next_tok then break end
          if next_tok.type == "comma" then break end
          if state:is_keyword("AS") then break end
          if state:is_keyword("FROM") then break end
          if state:is_keyword("INTO") then break end
          if state:is_keyword("WHERE") then break end
          state:advance()
        end
        -- Now current_col still has the first identifier (e.g., "Salary")
        -- If there's an AS next, it will be handled and create a proper column
        -- If not, we'll flush "Salary" as the column name at comma/FROM
      elseif current_source_table and paren_depth == 0 then
        -- alias.* pattern (e.g., "t.*")
        table.insert(columns, {
          name = "*",
          source_table = current_source_table,
          is_star = true,
        })
        current_source_table = nil
        current_col = nil
        state:advance()
      elseif paren_depth == 0 then
        -- Standalone * (SELECT *) at column level
        table.insert(columns, {
          name = "*",
          source_table = nil,
          is_star = true,
        })
        current_col = nil
        state:advance()
      else
        -- Star inside parentheses (e.g., COUNT(*)) - just skip it
        state:advance()
      end
    elseif token.type == "dot" then
      -- Previous identifier is a table qualifier
      if current_col then
        current_source_table = current_col
        current_col = nil
      end
      state:advance()
    elseif token.type == "identifier" or token.type == "bracket_id" then
      current_col = Helpers.strip_brackets(token.text)
      state:advance()

      -- Track qualified table.column reference for expression_columns
      if current_source_table then
        table.insert(current_expr_cols, {
          name = current_col,
          source_table = current_source_table,
        })
      end

      -- Check for AS keyword for alias
      if state:is_keyword("AS") then
        state:advance()
        local alias_token = state:current()
        -- Accept identifiers, bracket_ids, and keywords as aliases (SQL keywords can be valid aliases)
        if alias_token and (alias_token.type == "identifier" or alias_token.type == "bracket_id" or alias_token.type == "keyword") then
          current_col = Helpers.strip_brackets(alias_token.text)
          -- Don't clear current_source_table - preserve the table reference for the alias
          state:advance()
        end
      end
    elseif token.type == "comma" then
      -- End of current column
      if current_col then
        local col_entry = {
          name = current_col,
          source_table = current_source_table,
          is_star = false,
        }
        -- Include expression_columns when there are multiple contributing column refs
        if #current_expr_cols > 1 then
          col_entry.expression_columns = current_expr_cols
        end
        table.insert(columns, col_entry)
        current_col = nil
        current_source_table = nil
        current_expr_cols = {}
      end
      state:advance()
    elseif state:is_keyword("AS") then
      -- Handle AS keyword for expressions (e.g., "1 AS Level", "GETDATE() AS Today")
      -- This captures aliased expressions where the expression itself isn't tracked
      state:advance()
      local alias_token = state:current()
      -- Accept identifiers, bracket_ids, and keywords as aliases
      if alias_token and (alias_token.type == "identifier" or alias_token.type == "bracket_id" or alias_token.type == "keyword") then
        current_col = Helpers.strip_brackets(alias_token.text)
        state:advance()
      end
    else
      -- Other tokens (numbers, operators, etc.) - keep parsing
      state:advance()
    end
  end

  -- Add last column if any
  if current_col then
    local col_entry = {
      name = current_col,
      source_table = current_source_table,
      is_star = false,
    }
    if #current_expr_cols > 1 then
      col_entry.expression_columns = current_expr_cols
    end
    table.insert(columns, col_entry)
  end

  -- Update clause end position to just before FROM/INTO keyword
  -- This ensures cursor at "SELECT █ FROM" is still in SELECT clause
  if clause_pos then
    local next_keyword_token = state:current()  -- FROM or INTO token
    if next_keyword_token then
      -- Set end to just before the FROM/INTO token
      clause_pos.end_line = next_keyword_token.line
      clause_pos.end_col = next_keyword_token.col - 1
    else
      -- No FROM/INTO found, use last token processed
      local last_token = state.pos > 1 and state.tokens[state.pos - 1] or select_start_token
      if last_token then
        clause_pos.end_line = last_token.line
        clause_pos.end_col = last_token.col + #last_token.text - 1
      end
    end
  end

  return columns, clause_pos
end

return SelectListParser
