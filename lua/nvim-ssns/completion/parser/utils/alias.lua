---Alias parser for SQL identifiers
---Parses optional AS alias or implicit alias after table/column references
---
---@module ssns.completion.parser.utils.alias

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

local AliasParser = {}

---Keywords that should NEVER be accepted as aliases, even after explicit AS.
---These are clause-starting or statement-starting keywords that always indicate
---the end of the current clause rather than an alias.
---@type table<string, boolean>
local NEVER_ALIAS = {
  WHERE = true, JOIN = true, ON = true, SET = true, GROUP = true, ORDER = true,
  HAVING = true, VALUES = true, SELECT = true, INSERT = true, UPDATE = true,
  DELETE = true, FROM = true, INTO = true, UNION = true, INTERSECT = true,
  EXCEPT = true, INNER = true, LEFT = true, RIGHT = true, FULL = true,
  CROSS = true, OUTER = true, EXEC = true, EXECUTE = true, DECLARE = true,
  CREATE = true, ALTER = true, DROP = true, TRUNCATE = true, MERGE = true,
  WHEN = true, THEN = true, BEGIN = true, ["END"] = true, IF = true, ELSE = true,
  WHILE = true, RETURN = true, GRANT = true, REVOKE = true, WITH = true,
  GO = true,
}

---Parse an optional alias (AS alias or just alias)
---When explicit AS was consumed, keywords are accepted as aliases (except NEVER_ALIAS set).
---When implicit (no AS), only identifiers and bracket_ids are accepted.
---@param state ParserState
---@return string?
function AliasParser.parse(state)
  -- Check for AS keyword — track whether it was consumed
  local had_as = state:consume_keyword("AS")

  local token = state:current()
  if not token then return nil end

  -- Identifiers and bracket_ids always work as aliases
  if token.type == "identifier" or token.type == "bracket_id" then
    -- Don't treat GO as an alias
    if token.text:upper() == "GO" then return nil end
    local alias = Helpers.strip_brackets(token.text)
    state:advance()
    return alias
  end

  -- Keywords as aliases: only when preceded by explicit AS
  if token.type == "keyword" and had_as then
    if NEVER_ALIAS[token.text:upper()] then return nil end
    local alias = Helpers.strip_brackets(token.text)
    state:advance()
    return alias
  end

  return nil
end

return AliasParser
