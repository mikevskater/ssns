--- Column list parser utility
--- Parses parenthesized column lists like (col1, col2, col3)
---
--- Used by:
--- - CTE definitions: WITH cte (col1, col2) AS (...)
--- - VALUES table constructors: (VALUES ...) AS alias (col1, col2)
---
---@module ssns.completion.parser.utils.column_list

local Helpers = require('ssns.completion.parser.utils.helpers')

local ColumnListParser = {}

---Parse a parenthesized column list
---
---@param state ParserState Token navigation state (should be positioned at opening paren)
---@param options? {accept_keywords?: boolean} Parsing options
---@return string[] column_names List of column names (brackets stripped)
function ColumnListParser.parse(state, options)
  options = options or {}
  local column_list = {}

  if not state:is_type("paren_open") then
    return column_list
  end

  state:advance()  -- consume (

  while state:current() do
    local col_token = state:current()
    if col_token.type == "paren_close" then
      state:advance()
      break
    elseif col_token.type == "comma" then
      state:advance()
    elseif col_token.type == "identifier" or col_token.type == "bracket_id" then
      table.insert(column_list, Helpers.strip_brackets(col_token.text))
      state:advance()
    elseif options.accept_keywords and col_token.type == "keyword" then
      -- Some contexts allow keywords as column names (e.g., VALUES column lists)
      table.insert(column_list, Helpers.strip_brackets(col_token.text))
      state:advance()
    else
      state:advance()
    end
  end

  return column_list
end

return ColumnListParser
