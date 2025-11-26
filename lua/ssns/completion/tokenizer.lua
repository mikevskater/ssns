---@class Token
---@field type string TOKEN_TYPE value
---@field text string The token text
---@field line number 1-indexed line number
---@field col number 1-indexed column number

local TOKEN_TYPE = {
  KEYWORD = "keyword",         -- SELECT, FROM, WHERE, JOIN, etc.
  IDENTIFIER = "identifier",   -- table names, column names, aliases
  BRACKET_ID = "bracket_id",   -- [Bracketed Identifier]
  STRING = "string",           -- 'string literal'
  NUMBER = "number",           -- 123, 45.67
  OPERATOR = "operator",       -- =, <>, >=, +, -, *, /, etc.
  PAREN_OPEN = "paren_open",   -- (
  PAREN_CLOSE = "paren_close", -- )
  COMMA = "comma",             -- ,
  DOT = "dot",                 -- .
  SEMICOLON = "semicolon",     -- ; (emitted but ignored by parser)
  STAR = "star",               -- * (wildcard or multiply)
  GO = "go",                   -- GO batch separator
}

local STATE = {
  NORMAL = 1,
  IN_STRING = 2,           -- 'string literal' (handle '' escape)
  IN_BRACKET_ID = 3,       -- [Bracketed Identifier]
  IN_BLOCK_COMMENT = 4,    -- /* comment */ (supports nesting)
  IN_LINE_COMMENT = 5,     -- -- comment
}

-- SQL Keywords (case-insensitive)
local SQL_KEYWORDS = {
  SELECT = true, FROM = true, WHERE = true, JOIN = true, INNER = true,
  LEFT = true, RIGHT = true, OUTER = true, FULL = true, CROSS = true,
  ON = true, AND = true, OR = true, NOT = true, IN = true, EXISTS = true,
  BETWEEN = true, LIKE = true, IS = true, NULL = true, AS = true,
  INTO = true, INSERT = true, UPDATE = true, DELETE = true, CREATE = true,
  ALTER = true, DROP = true, TABLE = true, VIEW = true, INDEX = true,
  PROCEDURE = true, FUNCTION = true, TRIGGER = true, WITH = true,
  UNION = true, INTERSECT = true, EXCEPT = true, ORDER = true, BY = true,
  GROUP = true, HAVING = true, TOP = true, DISTINCT = true, ALL = true,
  ANY = true, CASE = true, WHEN = true, THEN = true, ELSE = true,
  END = true, DECLARE = true, SET = true, EXEC = true, EXECUTE = true,
  BEGIN = true, COMMIT = true, ROLLBACK = true, TRUNCATE = true,
  MERGE = true, VALUES = true, OUTPUT = true, RETURNS = true, RETURN = true,

  -- APPLY (T-SQL)
  APPLY = true,

  -- Type conversion / NULL handling
  CAST = true, COALESCE = true, NULLIF = true, CONVERT = true,

  -- Pagination (PostgreSQL, MySQL, SQLite)
  LIMIT = true, OFFSET = true, FETCH = true, NEXT = true, FIRST = true, ONLY = true,

  -- Window functions
  OVER = true, PARTITION = true, ROWS = true, RANGE = true, UNBOUNDED = true, PRECEDING = true, FOLLOWING = true, CURRENT = true, ROW = true,

  -- T-SQL specific
  PIVOT = true, UNPIVOT = true, OPENXML = true, OPENJSON = true,

  -- PostgreSQL specific
  RETURNING = true, LATERAL = true, ILIKE = true,

  -- SQLite specific
  PRAGMA = true, VACUUM = true, ATTACH = true, DETACH = true, GLOB = true,

  -- Control flow
  IF = true, WHILE = true, FOR = true, LOOP = true, CONTINUE = true, BREAK = true, GOTO = true,

  -- Constraints
  CONSTRAINT = true, PRIMARY = true, FOREIGN = true, KEY = true, REFERENCES = true, CHECK = true, UNIQUE = true, DEFAULT = true,

  -- Other common
  ASC = true, DESC = true, NULLS = true, LAST = true,
  NATURAL = true, USING = true,
  SOME = true, ESCAPE = true,
  GRANT = true, REVOKE = true,
  SCHEMA = true, DATABASE = true, USE = true,
  TEMPORARY = true, TEMP = true,
  CASCADE = true, RESTRICT = true,
  NO = true, ACTION = true,
  COLLATE = true,
}

-- Single-character operators (parser combines if needed)
local SINGLE_CHAR_OPERATORS = {
  ['='] = true, ['<'] = true, ['>'] = true,
  ['+'] = true, ['-'] = true, ['/'] = true, ['%'] = true,
  ['!'] = true, [':'] = true,
  ['&'] = true, ['|'] = true, ['^'] = true, ['~'] = true,
}

local Tokenizer = {}

---Check if a string is a SQL keyword
---@param text string
---@return boolean
local function is_keyword(text)
  return SQL_KEYWORDS[text:upper()] == true
end

---Check if a character is whitespace
---@param char string
---@return boolean
local function is_whitespace(char)
  return char == ' ' or char == '\t' or char == '\n' or char == '\r'
end

---Check if a character is a digit
---@param char string
---@return boolean
local function is_digit(char)
  return char >= '0' and char <= '9'
end

---Check if a character is alphabetic or underscore
---@param char string
---@return boolean
local function is_alpha(char)
  return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_'
end

---Check if a character is alphanumeric or underscore
---@param char string
---@return boolean
local function is_alnum(char)
  return is_alpha(char) or is_digit(char)
end

---Peek ahead in the text without consuming
---@param text string
---@param pos number
---@param offset number
---@return string|nil
local function peek(text, pos, offset)
  offset = offset or 1
  local new_pos = pos + offset
  if new_pos > #text then
    return nil
  end
  return text:sub(new_pos, new_pos)
end

---Tokenize SQL text into a token stream
---@param text string The SQL text to tokenize
---@return Token[] tokens Array of tokens with type, text, line, col
function Tokenizer.tokenize(text)
  if not text or text == "" then
    return {}
  end

  -- Preprocess: replace tabs with spaces to avoid tokenizing issues
  -- Tabs can cause stray operators when adjacent to tokens
  text = text:gsub("\t", " ")

  local tokens = {}
  local state = STATE.NORMAL
  local current_token = ""
  local token_start_line = 1
  local token_start_col = 1
  local line = 1
  local col = 1
  local comment_depth = 0
  local i = 1

  ---Emit the current accumulated token
  ---@param force_type string|nil Force a specific token type
  local function emit_token(force_type)
    if current_token == "" then
      return
    end

    local token_type = force_type

    if not token_type then
      -- Determine token type based on content
      if is_keyword(current_token) then
        -- Check for GO keyword (must be alone on line conceptually)
        if current_token:upper() == "GO" then
          token_type = TOKEN_TYPE.GO
        else
          token_type = TOKEN_TYPE.KEYWORD
        end
      elseif current_token:match("^%d+%.?%d*$") or current_token:match("^%d*%.%d+$") then
        -- Simple number detection (integer or decimal)
        token_type = TOKEN_TYPE.NUMBER
      else
        token_type = TOKEN_TYPE.IDENTIFIER
      end
    end

    table.insert(tokens, {
      type = token_type,
      text = current_token,
      line = token_start_line,
      col = token_start_col,
    })

    current_token = ""
  end

  ---Start a new token at current position
  local function start_token()
    token_start_line = line
    token_start_col = col
  end

  ---Emit a single-character token
  ---@param char string
  ---@param type string
  local function emit_single_char_token(char, type)
    emit_token() -- Emit any accumulated token first
    start_token()
    current_token = char
    emit_token(type)
  end

  while i <= #text do
    local char = text:sub(i, i)
    local next_char = peek(text, i)  -- Look at next character (offset 1 is default)

    if state == STATE.NORMAL then
      -- Check for whitespace
      if is_whitespace(char) then
        emit_token()
        -- Track line/col for newlines
        if char == '\n' then
          line = line + 1
          col = 1
        elseif char == '\r' then
          -- Handle \r\n or \r alone
          if next_char == '\n' then
            i = i + 1
          end
          line = line + 1
          col = 1
        else
          col = col + 1
        end
        i = i + 1

      -- Check for string literal start
      elseif char == "'" then
        emit_token()
        start_token()
        current_token = "'"
        state = STATE.IN_STRING
        col = col + 1
        i = i + 1

      -- Check for bracketed identifier start
      elseif char == '[' then
        emit_token()
        start_token()
        current_token = "["
        state = STATE.IN_BRACKET_ID
        col = col + 1
        i = i + 1

      -- Check for block comment start /*
      elseif char == '/' and next_char == '*' then
        emit_token()
        state = STATE.IN_BLOCK_COMMENT
        comment_depth = 1
        col = col + 2
        i = i + 2

      -- Check for line comment start --
      elseif char == '-' and next_char == '-' then
        emit_token()
        state = STATE.IN_LINE_COMMENT
        col = col + 2
        i = i + 2

      -- Check for star (special - used for SELECT *)
      elseif char == '*' then
        emit_single_char_token(char, TOKEN_TYPE.STAR)
        col = col + 1
        i = i + 1

      -- Check for single-character operators
      elseif SINGLE_CHAR_OPERATORS[char] then
        emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
        col = col + 1
        i = i + 1

      -- Check for single-character special tokens
      elseif char == '(' then
        emit_single_char_token(char, TOKEN_TYPE.PAREN_OPEN)
        col = col + 1
        i = i + 1

      elseif char == ')' then
        emit_single_char_token(char, TOKEN_TYPE.PAREN_CLOSE)
        col = col + 1
        i = i + 1

      elseif char == ',' then
        emit_single_char_token(char, TOKEN_TYPE.COMMA)
        col = col + 1
        i = i + 1

      elseif char == '.' then
        emit_single_char_token(char, TOKEN_TYPE.DOT)
        col = col + 1
        i = i + 1

      elseif char == ';' then
        emit_single_char_token(char, TOKEN_TYPE.SEMICOLON)
        col = col + 1
        i = i + 1

      else
        -- Accumulate into current token
        if current_token == "" then
          start_token()
        end
        current_token = current_token .. char
        col = col + 1
        i = i + 1
      end

    elseif state == STATE.IN_STRING then
      current_token = current_token .. char
      col = col + 1

      -- Check for escaped quote ''
      if char == "'" and next_char == "'" then
        current_token = current_token .. "'"
        col = col + 1
        i = i + 2
      elseif char == "'" then
        -- End of string
        emit_token(TOKEN_TYPE.STRING)
        state = STATE.NORMAL
        i = i + 1
      else
        i = i + 1
      end

    elseif state == STATE.IN_BRACKET_ID then
      current_token = current_token .. char
      col = col + 1

      if char == ']' then
        -- End of bracketed identifier
        emit_token(TOKEN_TYPE.BRACKET_ID)
        state = STATE.NORMAL
      end
      i = i + 1

    elseif state == STATE.IN_BLOCK_COMMENT then
      -- Check for nested comment start /*
      if char == '/' and next_char == '*' then
        comment_depth = comment_depth + 1
        col = col + 2
        i = i + 2
      -- Check for comment end */
      elseif char == '*' and next_char == '/' then
        comment_depth = comment_depth - 1
        col = col + 2
        i = i + 2
        if comment_depth == 0 then
          state = STATE.NORMAL
        end
      else
        -- Track line/col for newlines in comments
        if char == '\n' then
          line = line + 1
          col = 1
        elseif char == '\r' then
          if next_char == '\n' then
            i = i + 1
          end
          line = line + 1
          col = 1
        else
          col = col + 1
        end
        i = i + 1
      end

    elseif state == STATE.IN_LINE_COMMENT then
      if char == '\n' or char == '\r' then
        -- End of line comment
        state = STATE.NORMAL
        if char == '\r' and next_char == '\n' then
          i = i + 1
        end
        line = line + 1
        col = 1
        i = i + 1
      else
        col = col + 1
        i = i + 1
      end
    end
  end

  -- Emit any remaining token
  emit_token()

  return tokens
end

return Tokenizer
