-- Tokenize Worker
-- Performs SQL tokenization in a separate thread
-- Pure Lua only - NO vim.* APIs
--
-- Input: { text: string, options: table? }
-- Output: array of tokens with type, text, line, col, keyword_category
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local text = _INPUT.text or ""
local options = _INPUT.options or {}
local progress_interval = options.progress_interval or 10

-- ==========================================================================
-- Token Types (same as tokenizer.lua)
-- ==========================================================================

local TOKEN_TYPE = {
  KEYWORD = "keyword",
  IDENTIFIER = "identifier",
  BRACKET_ID = "bracket_id",
  STRING = "string",
  NUMBER = "number",
  OPERATOR = "operator",
  PAREN_OPEN = "paren_open",
  PAREN_CLOSE = "paren_close",
  COMMA = "comma",
  DOT = "dot",
  SEMICOLON = "semicolon",
  STAR = "star",
  GO = "go",
  AT = "at",
  VARIABLE = "variable",
  GLOBAL_VARIABLE = "global_variable",
  SYSTEM_PROCEDURE = "system_procedure",
  TEMP_TABLE = "temp_table",
  HASH = "hash",
  COMMENT = "comment",
  LINE_COMMENT = "line_comment",
}

local STATE = {
  NORMAL = 1,
  IN_STRING = 2,
  IN_BRACKET_ID = 3,
  IN_BLOCK_COMMENT = 4,
  IN_LINE_COMMENT = 5,
}

-- ==========================================================================
-- SQL Keyword Categories
-- ==========================================================================

local STATEMENT_KEYWORDS = {
  SELECT = true, INSERT = true, UPDATE = true, DELETE = true, MERGE = true,
  CREATE = true, ALTER = true, DROP = true, TRUNCATE = true,
  IF = true, ELSE = true, WHILE = true, BEGIN = true, END = true,
  RETURN = true, BREAK = true, CONTINUE = true, GOTO = true, RETURNS = true,
  TRY = true, CATCH = true, THROW = true, LOOP = true,
  COMMIT = true, ROLLBACK = true, TRANSACTION = true, TRAN = true, SAVEPOINT = true,
  EXEC = true, EXECUTE = true, DECLARE = true, SET = true, CALL = true,
  USE = true, PRINT = true, RAISERROR = true, WAITFOR = true,
  WITH = true, GO = true,
  BACKUP = true, RESTORE = true, CHECKPOINT = true, DBCC = true,
  GRANT = true, REVOKE = true, DENY = true,
  OPEN = true, CLOSE = true, FETCH = true, DEALLOCATE = true,
  PRAGMA = true, VACUUM = true, ATTACH = true, DETACH = true, EXPLAIN = true, SHOW = true, ANALYZE = true,
}

local CLAUSE_KEYWORDS = {
  FROM = true, WHERE = true, JOIN = true, ON = true,
  INNER = true, LEFT = true, RIGHT = true, OUTER = true, CROSS = true, FULL = true, NATURAL = true,
  GROUP = true, BY = true, HAVING = true, ORDER = true,
  INTO = true, VALUES = true, OUTPUT = true,
  UNION = true, INTERSECT = true, EXCEPT = true,
  TOP = true, DISTINCT = true, ALL = true,
  AS = true, OVER = true, PARTITION = true,
  CASE = true, WHEN = true, THEN = true,
  PIVOT = true, UNPIVOT = true, APPLY = true,
  OFFSET = true, NEXT = true, ROWS = true, ONLY = true,
  LIMIT = true, RETURNING = true,
  FOR = true, USING = true,
  MATCHED = true,
}

local FUNCTION_KEYWORDS = {
  COUNT = true, SUM = true, AVG = true, MIN = true, MAX = true,
  STRING_AGG = true, GROUPING = true, GROUPING_ID = true,
  STDEV = true, STDEVP = true, VAR = true, VARP = true,
  LEN = true, SUBSTRING = true, LTRIM = true, RTRIM = true, TRIM = true,
  UPPER = true, LOWER = true, REPLACE = true, STUFF = true,
  CHARINDEX = true, PATINDEX = true, CONCAT = true, CONCAT_WS = true,
  STRING_SPLIT = true, REVERSE = true, REPLICATE = true, SPACE = true, FORMAT = true,
  GETDATE = true, GETUTCDATE = true, SYSDATETIME = true,
  DATEADD = true, DATEDIFF = true, DATENAME = true, DATEPART = true,
  YEAR = true, MONTH = true, DAY = true, HOUR = true, MINUTE = true, SECOND = true,
  EOMONTH = true, DATEFROMPARTS = true, ISDATE = true, EXTRACT = true,
  CAST = true, CONVERT = true, TRY_CAST = true, TRY_CONVERT = true, PARSE = true,
  ISNULL = true, NULLIF = true, COALESCE = true, IIF = true, CHOOSE = true,
  GREATEST = true, LEAST = true,
  ABS = true, CEILING = true, FLOOR = true, ROUND = true,
  POWER = true, SQRT = true, SIGN = true, RAND = true, LN = true, MOD = true,
  NEWID = true, NEWSEQUENTIALID = true,
  SCOPE_IDENTITY = true, IDENT_CURRENT = true,
  ROW_NUMBER = true, RANK = true, DENSE_RANK = true, NTILE = true,
  LAG = true, LEAD = true, FIRST_VALUE = true, LAST_VALUE = true,
  ISNUMERIC = true,
}

local DATATYPE_KEYWORDS = {
  INT = true, INTEGER = true, BIGINT = true, SMALLINT = true, TINYINT = true,
  DECIMAL = true, NUMERIC = true, FLOAT = true, REAL = true, DOUBLE = true,
  MONEY = true, SMALLMONEY = true, BIT = true,
  CHAR = true, VARCHAR = true, NCHAR = true, NVARCHAR = true,
  TEXT = true, NTEXT = true, CHARACTER = true,
  BINARY = true, VARBINARY = true, IMAGE = true, BLOB = true, CLOB = true, NCLOB = true,
  DATE = true, TIME = true, DATETIME = true, DATETIME2 = true,
  SMALLDATETIME = true, DATETIMEOFFSET = true, TIMESTAMP = true, INTERVAL = true,
  UNIQUEIDENTIFIER = true, XML = true, JSON = true, SQL_VARIANT = true, ROWVERSION = true,
  GEOGRAPHY = true, GEOMETRY = true, HIERARCHYID = true,
  TABLE = true, CURSOR = true, BOOLEAN = true, ARRAY = true,
}

local OPERATOR_KEYWORDS = {
  AND = true, OR = true, NOT = true,
  IN = true, EXISTS = true, BETWEEN = true, LIKE = true, ILIKE = true, GLOB = true,
  IS = true, NULL = true, TRUE = true, FALSE = true,
  ANY = true, SOME = true,
  CONTAINS = true, FREETEXT = true, MATCH = true, SIMILAR = true,
  ESCAPE = true, OVERLAPS = true,
}

local CONSTRAINT_KEYWORDS = {
  PRIMARY = true, KEY = true, FOREIGN = true, REFERENCES = true,
  UNIQUE = true, CHECK = true, DEFAULT = true,
  CONSTRAINT = true, INDEX = true, CLUSTERED = true, NONCLUSTERED = true,
  IDENTITY = true, IDENTITY_INSERT = true, IDENTITYCOL = true, ROWGUIDCOL = true,
  CASCADE = true, RESTRICT = true, NOCHECK = true,
  ADD = true, COLUMN = true, MODIFY = true,
  SCHEMA = true, DATABASE = true, VIEW = true, PROCEDURE = true, PROC = true,
  FUNCTION = true, TRIGGER = true, SEQUENCE = true, RULE = true,
  FILLFACTOR = true, INCLUDE = true,
  COLLATE = true, COLLATION = true,
}

local MODIFIER_KEYWORDS = {
  ASC = true, DESC = true,
  NOLOCK = true, HOLDLOCK = true, UPDLOCK = true, READPAST = true,
  ROWLOCK = true, PAGLOCK = true, TABLOCK = true, TABLOCKX = true, XLOCK = true,
  READUNCOMMITTED = true, READCOMMITTEDLOCK = true, SERIALIZABLE = true, SNAPSHOT = true,
  FORCESEEK = true, FORCESCAN = true, NOEXPAND = true, NOWAIT = true,
  OPTION = true, MAXDOP = true, RECOMPILE = true, FAST = true, MAXRECURSION = true,
  UNBOUNDED = true, PRECEDING = true, FOLLOWING = true, CURRENT = true, RANGE = true, WINDOW = true,
  SCROLL = true, INSENSITIVE = true, KEYSET = true, FAST_FORWARD = true, READ_ONLY = true,
  PERCENT = true, TABLESAMPLE = true, RECURSIVE = true,
}

local MISC_KEYWORDS = {
  CURRENT_DATE = true, CURRENT_TIME = true, CURRENT_TIMESTAMP = true, CURRENT_USER = true,
  SESSION_USER = true, SYSTEM_USER = true, USER = true,
  AUTHORIZATION = true, PUBLIC = true, ROLE = true, ADMIN = true, PRIVILEGES = true, USAGE = true,
}

local GLOBAL_VARIABLE_KEYWORDS = {
  SERVERNAME = true, SERVICENAME = true, VERSION = true, LANGUAGE = true, LANGID = true,
  MAX_CONNECTIONS = true, MAX_PRECISION = true, MICROSOFTVERSION = true,
  ROWCOUNT = true, ERROR = true, TRANCOUNT = true,
  IDENTITY = true,
  FETCH_STATUS = true, CURSOR_ROWS = true,
  DATEFIRST = true, DBTS = true,
  CONNECTIONS = true, CPU_BUSY = true, IDLE = true, IO_BUSY = true,
  PACKET_ERRORS = true, PACK_RECEIVED = true, PACK_SENT = true,
  TOTAL_ERRORS = true, TOTAL_READ = true, TOTAL_WRITE = true, TIMETICKS = true,
  NESTLEVEL = true, OPTIONS = true, PROCID = true, SPID = true, TEXTSIZE = true,
  LOCK_TIMEOUT = true, DEF_SORTORDER_ID = true,
  REPLICATION = true,
}

local SYSTEM_PROCEDURE_KEYWORDS = {
  sp_help = true, sp_helptext = true, sp_helpdb = true, sp_helpindex = true,
  sp_columns = true, sp_tables = true, sp_stored_procedures = true,
  sp_databases = true, sp_fkeys = true, sp_pkeys = true,
  sp_rename = true, sp_executesql = true, sp_who = true, sp_who2 = true,
  sp_lock = true, sp_configure = true,
  xp_cmdshell = true, xp_msver = true, xp_fileexist = true, xp_fixeddrives = true,
  DBCC = true,
}

-- Build lookup: keyword -> category
local KEYWORD_TO_CATEGORY = {}
local category_tables = {
  { tbl = STATEMENT_KEYWORDS, category = "statement" },
  { tbl = CLAUSE_KEYWORDS, category = "clause" },
  { tbl = FUNCTION_KEYWORDS, category = "function" },
  { tbl = DATATYPE_KEYWORDS, category = "datatype" },
  { tbl = OPERATOR_KEYWORDS, category = "operator" },
  { tbl = CONSTRAINT_KEYWORDS, category = "constraint" },
  { tbl = MODIFIER_KEYWORDS, category = "modifier" },
  { tbl = MISC_KEYWORDS, category = "misc" },
}

for _, cat in ipairs(category_tables) do
  for keyword, _ in pairs(cat.tbl) do
    if not KEYWORD_TO_CATEGORY[keyword] then
      KEYWORD_TO_CATEGORY[keyword] = cat.category
    end
  end
end

-- Build flat lookup table
local SQL_KEYWORDS = {}
for keyword, _ in pairs(KEYWORD_TO_CATEGORY) do
  SQL_KEYWORDS[keyword] = true
end

-- Single-character operators
local SINGLE_CHAR_OPERATORS = {
  ['='] = true, ['<'] = true, ['>'] = true,
  ['+'] = true, ['-'] = true, ['/'] = true, ['%'] = true,
  ['!'] = true, [':'] = true,
  ['&'] = true, ['|'] = true, ['^'] = true, ['~'] = true,
}

-- ==========================================================================
-- Helper Functions
-- ==========================================================================

local function is_keyword(txt)
  return SQL_KEYWORDS[txt:upper()] == true
end

local function is_whitespace(char)
  return char == ' ' or char == '\t' or char == '\n' or char == '\r'
end

local function is_digit(char)
  return char >= '0' and char <= '9'
end

local function is_alpha(char)
  return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_'
end

local function is_alnum(char)
  return is_alpha(char) or is_digit(char)
end

local function peek(txt, pos, offset)
  offset = offset or 1
  local new_pos = pos + offset
  if new_pos > #txt then
    return nil
  end
  return txt:sub(new_pos, new_pos)
end

-- ==========================================================================
-- Main Processing
-- ==========================================================================

if text == "" then
  send({ type = "complete", result = { tokens = {}, total_chars = 0 } })
  return
end

-- Preprocess: replace tabs with spaces
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
local last_token_type = nil
local total_chars = #text
local last_progress = 0

local function emit_token(force_type)
  if current_token == "" then
    return
  end

  local token_type = force_type
  local keyword_category = nil

  if not token_type then
    if is_keyword(current_token) then
      local upper = current_token:upper()
      if upper == "GO" then
        token_type = TOKEN_TYPE.GO
        keyword_category = "statement"
      else
        token_type = TOKEN_TYPE.KEYWORD
        keyword_category = KEYWORD_TO_CATEGORY[upper]
      end
    elseif current_token:match("^%-?%d+%.?%d*$") or current_token:match("^%-?%d*%.%d+$") or current_token:match("^%-?0[xX][0-9a-fA-F]+$") then
      token_type = TOKEN_TYPE.NUMBER
    elseif SYSTEM_PROCEDURE_KEYWORDS[current_token] or SYSTEM_PROCEDURE_KEYWORDS[current_token:lower()] then
      token_type = TOKEN_TYPE.SYSTEM_PROCEDURE
      keyword_category = "system_procedure"
    else
      token_type = TOKEN_TYPE.IDENTIFIER
    end
  elseif token_type == TOKEN_TYPE.GLOBAL_VARIABLE then
    keyword_category = "global_variable"
  elseif token_type == TOKEN_TYPE.SYSTEM_PROCEDURE then
    keyword_category = "system_procedure"
  end

  table.insert(tokens, {
    type = token_type,
    text = current_token,
    line = token_start_line,
    col = token_start_col,
    keyword_category = keyword_category,
  })

  last_token_type = token_type
  current_token = ""
end

local function start_token()
  token_start_line = line
  token_start_col = col
end

local function emit_single_char_token(char, type)
  emit_token()
  start_token()
  current_token = char
  emit_token(type)
end

-- Process the text
while i <= #text do
  local char = text:sub(i, i)
  local next_char = peek(text, i)

  if state == STATE.NORMAL then
    if is_whitespace(char) then
      emit_token()
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

    elseif char == "'" then
      if current_token:upper() == "N" then
        current_token = current_token .. "'"
        state = STATE.IN_STRING
        col = col + 1
        i = i + 1
      else
        emit_token()
        start_token()
        current_token = "'"
        state = STATE.IN_STRING
        col = col + 1
        i = i + 1
      end

    elseif char == '[' then
      emit_token()
      start_token()
      current_token = "["
      state = STATE.IN_BRACKET_ID
      col = col + 1
      i = i + 1

    elseif char == '/' and next_char == '*' then
      emit_token()
      start_token()
      current_token = "/*"
      state = STATE.IN_BLOCK_COMMENT
      comment_depth = 1
      col = col + 2
      i = i + 2

    elseif char == '-' and next_char == '-' then
      emit_token()
      start_token()
      current_token = "--"
      state = STATE.IN_LINE_COMMENT
      col = col + 2
      i = i + 2

    elseif char == '*' then
      emit_single_char_token(char, TOKEN_TYPE.STAR)
      col = col + 1
      i = i + 1

    elseif char == '-' and next_char and (next_char:match("%d") or (next_char == '.' and peek(text, i + 1) and peek(text, i + 1):match("%d"))) then
      local is_negative_number_context = (
        last_token_type == nil or
        last_token_type == TOKEN_TYPE.OPERATOR or
        last_token_type == TOKEN_TYPE.COMMA or
        last_token_type == TOKEN_TYPE.PAREN_OPEN or
        last_token_type == TOKEN_TYPE.KEYWORD or
        last_token_type == TOKEN_TYPE.GO or
        last_token_type == TOKEN_TYPE.SEMICOLON
      )

      if is_negative_number_context and current_token == "" then
        start_token()
        current_token = "-"
        col = col + 1
        i = i + 1
      else
        emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
        col = col + 1
        i = i + 1
      end

    elseif SINGLE_CHAR_OPERATORS[char] then
      if char == '<' and next_char then
        if next_char == '>' then
          emit_single_char_token('<>', TOKEN_TYPE.OPERATOR)
          col = col + 2
          i = i + 2
        elseif next_char == '=' then
          emit_single_char_token('<=', TOKEN_TYPE.OPERATOR)
          col = col + 2
          i = i + 2
        else
          emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
          col = col + 1
          i = i + 1
        end
      elseif char == '>' and next_char and next_char == '=' then
        emit_single_char_token('>=', TOKEN_TYPE.OPERATOR)
        col = col + 2
        i = i + 2
      elseif char == '!' and next_char and next_char == '=' then
        emit_single_char_token('!=', TOKEN_TYPE.OPERATOR)
        col = col + 2
        i = i + 2
      elseif char == ':' and next_char and next_char == ':' then
        emit_single_char_token('::', TOKEN_TYPE.OPERATOR)
        col = col + 2
        i = i + 2
      else
        emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
        col = col + 1
        i = i + 1
      end

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
      local is_decimal_number = false
      if next_char and next_char:match("%d") then
        if current_token == "" or current_token:match("^%-?%d+$") then
          is_decimal_number = true
        end
      end

      if is_decimal_number then
        if current_token == "" then
          start_token()
        end
        current_token = current_token .. char
        col = col + 1
        i = i + 1
      else
        emit_single_char_token(char, TOKEN_TYPE.DOT)
        col = col + 1
        i = i + 1
      end

    elseif char == ';' then
      emit_single_char_token(char, TOKEN_TYPE.SEMICOLON)
      col = col + 1
      i = i + 1

    elseif char == '@' then
      emit_token()
      start_token()
      if next_char == '@' then
        local global_var = "@@"
        local j = i + 2
        while j <= #text do
          local c = text:sub(j, j)
          if is_alnum(c) then
            global_var = global_var .. c
            j = j + 1
          else
            break
          end
        end
        current_token = global_var
        emit_token(TOKEN_TYPE.GLOBAL_VARIABLE)
        col = col + #global_var
        i = j
      elseif next_char and is_alnum(next_char) then
        local user_var = "@"
        local j = i + 1
        while j <= #text do
          local c = text:sub(j, j)
          if is_alnum(c) then
            user_var = user_var .. c
            j = j + 1
          else
            break
          end
        end
        current_token = user_var
        emit_token(TOKEN_TYPE.VARIABLE)
        col = col + #user_var
        i = j
      else
        emit_single_char_token(char, TOKEN_TYPE.AT)
        col = col + 1
        i = i + 1
      end

    elseif char == '#' then
      emit_token()
      start_token()
      local temp_table = "#"
      local j = i + 1
      if j <= #text and text:sub(j, j) == '#' then
        temp_table = "##"
        j = j + 1
      end
      while j <= #text do
        local c = text:sub(j, j)
        if is_alnum(c) then
          temp_table = temp_table .. c
          j = j + 1
        else
          break
        end
      end
      if #temp_table > 1 and (temp_table:sub(2, 2) ~= '#' or #temp_table > 2) then
        current_token = temp_table
        emit_token(TOKEN_TYPE.TEMP_TABLE)
      else
        current_token = temp_table
        emit_token(TOKEN_TYPE.HASH)
      end
      col = col + #temp_table
      i = j

    else
      if current_token == "" then
        start_token()
      end
      current_token = current_token .. char
      col = col + 1
      i = i + 1
    end

  elseif state == STATE.IN_STRING then
    if char == "'" and next_char == "'" then
      current_token = current_token .. "''"
      col = col + 2
      i = i + 2
    elseif char == "'" then
      current_token = current_token .. char
      emit_token(TOKEN_TYPE.STRING)
      state = STATE.NORMAL
      col = col + 1
      i = i + 1
    else
      current_token = current_token .. char
      if char == '\n' then
        line = line + 1
        col = 1
        i = i + 1
      elseif char == '\r' then
        if next_char == '\n' then
          current_token = current_token .. '\n'
          i = i + 2
        else
          i = i + 1
        end
        line = line + 1
        col = 1
      else
        col = col + 1
        i = i + 1
      end
    end

  elseif state == STATE.IN_BRACKET_ID then
    current_token = current_token .. char
    col = col + 1
    if char == ']' then
      emit_token(TOKEN_TYPE.BRACKET_ID)
      state = STATE.NORMAL
    end
    i = i + 1

  elseif state == STATE.IN_BLOCK_COMMENT then
    if char == '/' and next_char == '*' then
      comment_depth = comment_depth + 1
      current_token = current_token .. "/*"
      col = col + 2
      i = i + 2
    elseif char == '*' and next_char == '/' then
      comment_depth = comment_depth - 1
      current_token = current_token .. "*/"
      col = col + 2
      i = i + 2
      if comment_depth == 0 then
        emit_token(TOKEN_TYPE.COMMENT)
        state = STATE.NORMAL
      end
    else
      current_token = current_token .. char
      if char == '\n' then
        line = line + 1
        col = 1
        i = i + 1
      elseif char == '\r' then
        if next_char == '\n' then
          current_token = current_token .. '\n'
          i = i + 2
        else
          i = i + 1
        end
        line = line + 1
        col = 1
      else
        col = col + 1
        i = i + 1
      end
    end

  elseif state == STATE.IN_LINE_COMMENT then
    if char == '\n' or char == '\r' then
      emit_token(TOKEN_TYPE.LINE_COMMENT)
      state = STATE.NORMAL
      if char == '\r' and next_char == '\n' then
        i = i + 2
      else
        i = i + 1
      end
      line = line + 1
      col = 1
    else
      current_token = current_token .. char
      col = col + 1
      i = i + 1
    end
  end

  -- Send progress updates
  local current_progress = math.floor((i / total_chars) * 10) * 10
  if current_progress > last_progress then
    last_progress = current_progress
    send({
      type = "progress",
      pct = current_progress,
      message = string.format("Tokenizing %d/%d characters...", i, total_chars),
    })
  end
end

-- Handle EOF cases
if state == STATE.IN_LINE_COMMENT and current_token ~= "" then
  emit_token(TOKEN_TYPE.LINE_COMMENT)
elseif state == STATE.IN_BLOCK_COMMENT and current_token ~= "" then
  emit_token(TOKEN_TYPE.COMMENT)
else
  emit_token()
end

-- Send completion
send({
  type = "complete",
  result = { tokens = tokens, total_chars = total_chars },
})
