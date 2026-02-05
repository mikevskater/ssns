--- Column definitions parser module
--- Parses column definitions in CREATE TABLE and DECLARE @var TABLE statements
---
--- Handles:
--- - Column definitions: (col1 TYPE, col2 TYPE NOT NULL, ...)
--- - Constraint definitions: PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, etc.
--- - Parameterized types: VARCHAR(50), DECIMAL(10,2)
--- - Column modifiers: NULL, NOT NULL, DEFAULT, IDENTITY, etc.
---
---@module ssns.completion.parser.clauses.column_defs

local Helpers = require('nvim-ssns.completion.parser.utils.helpers')

local ColumnDefsParser = {}

--- Constraint keywords that should be skipped when parsing column definitions
local CONSTRAINT_KEYWORDS = {
  PRIMARY = true,
  FOREIGN = true,
  UNIQUE = true,
  CHECK = true,
  CONSTRAINT = true,
  INDEX = true,
  CLUSTERED = true,
  NONCLUSTERED = true,
}

---@class ColumnDefinition
---@field name string Column name
---@field data_type string? Data type (e.g., "INT", "VARCHAR")
---@field is_star boolean Always false for column definitions

---Parse column definitions from a parenthesized list
---Expects parser to be positioned AT the opening parenthesis.
---
---@param state ParserState Token navigation state
---@return ColumnDefinition[] columns The parsed column definitions
function ColumnDefsParser.parse(state)
  local columns = {}

  if not state:is_type("paren_open") then
    return columns
  end

  state:advance()  -- consume (

  while state:current() and not state:is_type("paren_close") do
    local token = state:current()

    -- Skip constraint definitions
    if ColumnDefsParser._is_constraint_keyword(token) then
      ColumnDefsParser._skip_constraint(state)
      goto continue_column
    end

    -- Parse column name
    -- Note: SQL allows keywords as column names (e.g., NewID, Status)
    -- We check for identifier, bracket_id, OR keyword that isn't a constraint keyword
    if token.type == "identifier" or token.type == "bracket_id" or token.type == "keyword" then
      local col_name = Helpers.strip_brackets(token.text)
      state:advance()

      -- Parse data type
      local data_type = ColumnDefsParser._parse_data_type(state)

      -- Add column to list
      table.insert(columns, {
        name = col_name,
        data_type = data_type,
        is_star = false,
      })

      -- Skip remaining column modifiers (NULL, NOT NULL, DEFAULT, IDENTITY, etc.)
      ColumnDefsParser._skip_column_modifiers(state)

      -- Skip comma if present
      if state:is_type("comma") then
        state:advance()
      end
    else
      -- Unknown token, skip it
      state:advance()
    end

    ::continue_column::
  end

  -- Consume closing paren
  if state:is_type("paren_close") then
    state:advance()
  end

  return columns
end

---Check if token is a constraint keyword
---@param token table
---@return boolean
---@private
function ColumnDefsParser._is_constraint_keyword(token)
  if not token or token.type ~= "keyword" then
    return false
  end
  return CONSTRAINT_KEYWORDS[token.text:upper()] == true
end

---Skip a constraint definition until comma or closing paren
---@param state ParserState
---@private
function ColumnDefsParser._skip_constraint(state)
  while state:current() and not state:is_type("comma") and not state:is_type("paren_close") do
    if state:is_type("paren_open") then
      -- Skip parenthesized content (column list, etc.)
      state:skip_paren_contents()
    else
      state:advance()
    end
  end

  -- Skip comma if present
  if state:is_type("comma") then
    state:advance()
  end
end

---Parse a data type (INT, VARCHAR(50), DECIMAL(10,2), etc.)
---@param state ParserState
---@return string? data_type
---@private
function ColumnDefsParser._parse_data_type(state)
  local type_token = state:current()

  if not type_token or (type_token.type ~= "keyword" and type_token.type ~= "identifier") then
    return nil
  end

  local data_type = type_token.text:upper()
  state:advance()

  -- Handle parameterized types like VARCHAR(50), DECIMAL(10,2)
  if state:is_type("paren_open") then
    state:skip_paren_contents()
  end

  return data_type
end

---Skip column modifiers (NULL, NOT NULL, DEFAULT, IDENTITY, etc.)
---@param state ParserState
---@private
function ColumnDefsParser._skip_column_modifiers(state)
  while state:current() and not state:is_type("comma") and not state:is_type("paren_close") do
    if state:is_type("paren_open") then
      -- Skip parenthesized content (DEFAULT value, IDENTITY seed, etc.)
      state:skip_paren_contents()
    else
      state:advance()
    end
  end
end

return ColumnDefsParser
