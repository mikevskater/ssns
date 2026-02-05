---Alias parser for SQL identifiers
---Parses optional AS alias or implicit alias after table/column references
---
---@module ssns.completion.parser.utils.alias

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

local AliasParser = {}

---Parse an optional alias (AS alias or just alias)
---@param state ParserState
---@return string?
function AliasParser.parse(state)
  -- Check for AS keyword
  state:consume_keyword("AS")

  -- Next token should be identifier (but not GO batch separator)
  local token = state:current()
  if token and (token.type == "identifier" or token.type == "bracket_id") then
    -- Don't treat GO as an alias
    if token.text:upper() == "GO" then
      return nil
    end
    local alias = Helpers.strip_brackets(token.text)
    state:advance()
    return alias
  end

  return nil
end

return AliasParser
