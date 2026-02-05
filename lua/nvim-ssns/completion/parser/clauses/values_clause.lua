--- VALUES clause parser module
--- Parses VALUES clauses in different SQL contexts
---
--- Handles:
--- - FROM clause: VALUES table constructor (VALUES (row1), (row2)) AS alias(col1, col2)
--- - INSERT clause: INSERT VALUES (v1, v2), (v3, v4)
---
---@module ssns.completion.parser.clauses.values_clause

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local AliasParser = require('nvim-ssns.completion.parser.utils.alias')
local ColumnListParser = require('nvim-ssns.completion.parser.utils.column_list')

local ValuesClauseParser = {}

---Parse VALUES table constructor in FROM clause context
---Creates a virtual subquery for: (VALUES (row1), (row2)) AS alias(col1, col2)
---
---Note: This expects the parser to be positioned AFTER the opening paren,
---AT the VALUES keyword.
---
---@param state ParserState Token navigation state
---@param open_paren_token table The opening paren token (for position tracking)
---@return SubqueryInfo? subquery The virtual subquery representing the VALUES table
function ValuesClauseParser.parse_table_constructor(state, open_paren_token)
  if not state:is_keyword("VALUES") then
    return nil
  end

  state:advance()  -- consume VALUES

  -- Skip value rows - count parens to find end of (VALUES ...)
  local values_depth = 0
  while state:current() do
    local vtok = state:current()
    if vtok.type == "paren_open" then
      values_depth = values_depth + 1
    elseif vtok.type == "paren_close" then
      if values_depth == 0 then
        break  -- Found the closing ) for (VALUES ...)
      end
      values_depth = values_depth - 1
    end
    state:advance()
  end

  -- Consume closing paren
  local end_token = state:current()
  if state:is_type("paren_close") then
    state:advance()
  end

  -- Parse alias with column list: AS v(ID, Letter)
  local values_alias = AliasParser.parse(state)
  if not values_alias then
    return nil
  end

  -- Check for column list
  local column_list = ColumnListParser.parse(state, { accept_keywords = true })

  -- Create a virtual subquery for the VALUES table
  ---@type SubqueryInfo
  local values_subquery = {
    alias = values_alias,
    columns = {},
    tables = {},
    subqueries = {},
    parameters = {},
    is_values = true,
    start_pos = { line = open_paren_token.line, col = open_paren_token.col },
    end_pos = end_token and { line = end_token.line, col = end_token.col } or { line = open_paren_token.line, col = open_paren_token.col },
    clause_positions = {},
  }

  -- Add columns from column list
  for _, col_name in ipairs(column_list) do
    table.insert(values_subquery.columns, {
      name = col_name,
      source_table = values_alias,
      is_star = false,
    })
  end

  return values_subquery
end

---Parse INSERT VALUES clause
---Handles: VALUES (v1, v2), (v3, v4), ...
---
---Note: This expects the parser to be positioned AT the VALUES keyword.
---
---@param state ParserState Token navigation state
---@return ClausePosition? clause_pos Position of the VALUES clause
function ValuesClauseParser.parse_insert_values(state)
  if not state:is_keyword("VALUES") then
    return nil
  end

  local values_token = state:current()
  state:advance()  -- consume VALUES

  -- VALUES can have multiple row sets: VALUES (...), (...)
  local first_values_paren = nil
  local last_values_token = values_token

  while state:current() do
    if state:is_type("paren_open") then
      if not first_values_paren then
        first_values_paren = state:current()
      end

      -- Skip this VALUES row
      local paren_depth = 1
      state:advance()  -- consume (

      while state:current() and paren_depth > 0 do
        if state:is_type("paren_open") then
          paren_depth = paren_depth + 1
        elseif state:is_type("paren_close") then
          paren_depth = paren_depth - 1
        end
        last_values_token = state:current()
        state:advance()
      end
    elseif state:is_type("comma") then
      -- Multi-row VALUES: VALUES (...), (...)
      state:advance()
    else
      break  -- Not part of VALUES clause
    end
  end

  -- Return VALUES clause position (from VALUES keyword to last closing paren)
  if first_values_paren then
    return {
      start_line = values_token.line,
      start_col = values_token.col,
      end_line = last_values_token.line,
      end_col = last_values_token.col + #last_values_token.text - 1,
    }
  end

  return nil
end

return ValuesClauseParser
