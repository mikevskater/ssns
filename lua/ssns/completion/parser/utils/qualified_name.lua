---Qualified name parser for SQL identifiers
---Parses server.database.schema.name qualified identifiers
---
---@module ssns.completion.parser.utils.qualified_name

local Helpers = require('ssns.completion.parser.utils.helpers')

local QualifiedName = {}

---@class QualifiedIdentifier
---@field server string?
---@field database string?
---@field schema string?
---@field name string

---Parse a qualified identifier (server.db.schema.table or fewer parts)
---Handles temp table prefixes (#, ##) and table variable prefix (@)
---@param state ParserState
---@return QualifiedIdentifier?
function QualifiedName.parse(state)
  local parts = {}
  local prefix = ""  -- For # or ## temp table prefixes, or @ for table variables

  -- Check for temp_table token (#temp or ##temp as single token)
  if state:is_type("temp_table") then
    local token = state:current()
    -- The token text already includes the # or ## prefix
    table.insert(parts, token.text)
    state:advance()
    -- Temp tables don't have additional qualified parts, return directly
    return { server = nil, database = nil, schema = nil, name = token.text }
  end

  -- Check for variable token (@var as single token) - for table variables
  if state:is_type("variable") then
    local token = state:current()
    -- The token text already includes the @ prefix
    table.insert(parts, token.text)
    state:advance()
    -- Table variables don't have additional qualified parts, return directly
    return { server = nil, database = nil, schema = nil, name = token.text }
  end

  -- Legacy handling for hash token (# or ##) - keep for compatibility
  if state:is_type("hash") then
    prefix = "#"
    state:advance()
    -- Check for second # (global temp table)
    if state:is_type("hash") then
      prefix = "##"
      state:advance()
    end
  -- Legacy handling for at token (@) - keep for compatibility
  elseif state:is_type("at") then
    prefix = "@"
    state:advance()
  end

  -- Read first part
  local token = state:current()
  if not token then
    return nil
  end

  if token.type == "identifier" or token.type == "bracket_id" or token.type == "keyword" then
    local name = Helpers.strip_brackets(token.text)
    -- Prepend prefix if present (temp table or table variable)
    if prefix ~= "" then
      name = prefix .. name
    end
    table.insert(parts, name)
    state:advance()
  else
    -- If we consumed a prefix but no identifier follows, return nil
    if prefix ~= "" then
      return nil
    end
    return nil
  end

  -- Read additional parts separated by dots
  while state:is_type("dot") do
    state:advance()
    token = state:current()
    if token and (token.type == "identifier" or token.type == "bracket_id") then
      table.insert(parts, Helpers.strip_brackets(token.text))
      state:advance()
    else
      break
    end
  end

  -- Map parts to server.database.schema.name
  if #parts == 1 then
    return { server = nil, database = nil, schema = nil, name = parts[1] }
  elseif #parts == 2 then
    return { server = nil, database = nil, schema = parts[1], name = parts[2] }
  elseif #parts == 3 then
    return { server = nil, database = parts[1], schema = parts[2], name = parts[3] }
  elseif #parts == 4 then
    return { server = parts[1], database = parts[2], schema = parts[3], name = parts[4] }
  else
    -- More than 4 parts - use last 4
    local n = #parts
    return { server = parts[n-3], database = parts[n-2], schema = parts[n-1], name = parts[n] }
  end
end

return QualifiedName
