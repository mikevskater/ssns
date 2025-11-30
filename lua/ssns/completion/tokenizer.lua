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
  AT = "at",                   -- @ for variables/parameters (@UserId, @@ROWCOUNT)
  HASH = "hash",               -- # for temp tables (#temp, ##global)
}

local STATE = {
  NORMAL = 1,
  IN_STRING = 2,           -- 'string literal' (handle '' escape)
  IN_BRACKET_ID = 3,       -- [Bracketed Identifier]
  IN_BLOCK_COMMENT = 4,    -- /* comment */ (supports nesting)
  IN_LINE_COMMENT = 5,     -- -- comment
}

-- SQL Keywords (case-insensitive)
-- Comprehensive list from Microsoft SQL Server documentation
-- Source: https://learn.microsoft.com/en-us/sql/t-sql/language-elements/reserved-keywords-transact-sql
local SQL_KEYWORDS = {
  -- ==========================================================================
  -- SQL Server and Azure Synapse Analytics Reserved Keywords
  -- ==========================================================================
  ADD = true, ALL = true, ALTER = true, AND = true, ANY = true, AS = true, ASC = true, AUTHORIZATION = true,
  BACKUP = true, BEGIN = true, BETWEEN = true, BREAK = true, BROWSE = true, BULK = true, BY = true,
  CASCADE = true, CASE = true, CHECK = true, CHECKPOINT = true, CLOSE = true, CLUSTERED = true,
  COALESCE = true, COLLATE = true, COLUMN = true, COMMIT = true, COMPUTE = true, CONSTRAINT = true,
  CONTAINS = true, CONTAINSTABLE = true, CONTINUE = true, CONVERT = true, CREATE = true, CROSS = true,
  CURRENT = true, CURRENT_DATE = true, CURRENT_TIME = true, CURRENT_TIMESTAMP = true, CURRENT_USER = true, CURSOR = true,
  DATABASE = true, DBCC = true, DEALLOCATE = true, DECLARE = true, DEFAULT = true, DELETE = true,
  DENY = true, DESC = true, DISK = true, DISTINCT = true, DISTRIBUTED = true, DOUBLE = true, DROP = true, DUMP = true,
  ELSE = true, END = true, ERRLVL = true, ESCAPE = true, EXCEPT = true, EXEC = true, EXECUTE = true,
  EXISTS = true, EXIT = true, EXTERNAL = true,
  FETCH = true, FILE = true, FILLFACTOR = true, FOR = true, FOREIGN = true, FREETEXT = true,
  FREETEXTTABLE = true, FROM = true, FULL = true, FUNCTION = true,
  GOTO = true, GRANT = true, GROUP = true,
  HAVING = true, HOLDLOCK = true,
  IDENTITY = true, IDENTITY_INSERT = true, IDENTITYCOL = true, IF = true, IN = true, INDEX = true,
  INNER = true, INSERT = true, INTERSECT = true, INTO = true, IS = true,
  JOIN = true,
  KEY = true, KILL = true,
  LEFT = true, LIKE = true, LINENO = true, LOAD = true,
  MERGE = true,
  NATIONAL = true, NOCHECK = true, NONCLUSTERED = true, NOT = true, NULL = true, NULLIF = true,
  OF = true, OFF = true, OFFSETS = true, ON = true, OPEN = true, OPENDATASOURCE = true,
  OPENQUERY = true, OPENROWSET = true, OPENXML = true, OPTION = true, OR = true, ORDER = true, OUTER = true, OVER = true,
  PERCENT = true, PIVOT = true, PLAN = true, PRECISION = true, PRIMARY = true, PRINT = true,
  PROC = true, PROCEDURE = true, PUBLIC = true,
  RAISERROR = true, READ = true, READTEXT = true, RECONFIGURE = true, REFERENCES = true,
  REPLICATION = true, RESTORE = true, RESTRICT = true, RETURN = true, REVERT = true, REVOKE = true,
  RIGHT = true, ROLLBACK = true, ROWCOUNT = true, ROWGUIDCOL = true, RULE = true,
  SAVE = true, SCHEMA = true, SECURITYAUDIT = true, SELECT = true,
  SEMANTICKEYPHRASETABLE = true, SEMANTICSIMILARITYDETAILSTABLE = true, SEMANTICSIMILARITYTABLE = true,
  SESSION_USER = true, SET = true, SETUSER = true, SHUTDOWN = true, SOME = true, STATISTICS = true, SYSTEM_USER = true,
  TABLE = true, TABLESAMPLE = true, TEXTSIZE = true, THEN = true, TO = true, TOP = true,
  TRAN = true, TRANSACTION = true, TRIGGER = true, TRUNCATE = true, TRY_CONVERT = true, TSEQUAL = true,
  UNION = true, UNIQUE = true, UNPIVOT = true, UPDATE = true, UPDATETEXT = true, USE = true, USER = true,
  VALUES = true, VARYING = true, VIEW = true,
  WAITFOR = true, WHEN = true, WHERE = true, WHILE = true, WITH = true, WITHIN = true, WRITETEXT = true,

  -- Azure Synapse Analytics specific
  LABEL = true,

  -- ==========================================================================
  -- ODBC Reserved Keywords (common subset)
  -- ==========================================================================
  ABSOLUTE = true, ACTION = true, ALLOCATE = true, ARE = true, ASSERTION = true, AT = true,
  BIT = true, BIT_LENGTH = true, BOTH = true,
  CASCADED = true, CAST = true, CATALOG = true, CHAR = true, CHAR_LENGTH = true, CHARACTER = true,
  CHARACTER_LENGTH = true, COLLATION = true, CONNECT = true, CONNECTION = true, CONSTRAINTS = true, CORRESPONDING = true,
  DATE = true, DAY = true, DEC = true, DECIMAL = true, DEFERRABLE = true, DEFERRED = true,
  DESCRIBE = true, DESCRIPTOR = true, DIAGNOSTICS = true, DISCONNECT = true, DOMAIN = true,
  EXCEPTION = true, EXTRACT = true,
  FALSE = true, FLOAT = true, FOUND = true,
  GET = true, GLOBAL = true, GO = true,
  HOUR = true,
  IMMEDIATE = true, INCLUDE = true, INDICATOR = true, INITIALLY = true, INPUT = true, INSENSITIVE = true,
  INT = true, INTEGER = true, INTERVAL = true, ISOLATION = true,
  LANGUAGE = true, LAST = true, LEADING = true, LEVEL = true, LOCAL = true, LOCALTIME = true, LOCALTIMESTAMP = true, LOWER = true,
  MATCH = true, MAX = true, MIN = true, MINUTE = true, MODULE = true, MONTH = true,
  NAMES = true, NATURAL = true, NCHAR = true, NEXT = true, NO = true, NONE = true, NUMERIC = true,
  OCTET_LENGTH = true, ONLY = true, OUTPUT = true, OVERLAPS = true,
  PAD = true, PARTIAL = true, POSITION = true, PREPARE = true, PRESERVE = true, PRIOR = true, PRIVILEGES = true,
  REAL = true, RELATIVE = true,
  ROWS = true, SCROLL = true, SECOND = true, SECTION = true, SESSION = true, SIZE = true, SMALLINT = true,
  SPACE = true, SQL = true, SQLCA = true, SQLCODE = true, SQLERROR = true, SQLSTATE = true, SQLWARNING = true,
  SUBSTRING = true, SUM = true,
  TEMPORARY = true, TIME = true, TIMESTAMP = true, TIMEZONE_HOUR = true, TIMEZONE_MINUTE = true,
  TRAILING = true, TRANSLATE = true, TRANSLATION = true, TRIM = true, TRUE = true,
  UNKNOWN = true, UPPER = true, USAGE = true, USING = true,
  VALUE = true, VARCHAR = true, WHENEVER = true, WORK = true, WRITE = true,
  YEAR = true, ZONE = true,

  -- ==========================================================================
  -- Future Reserved Keywords (commonly used)
  -- ==========================================================================
  ADMIN = true, AFTER = true, AGGREGATE = true, ALIAS = true, ARRAY = true, ASENSITIVE = true, ASYMMETRIC = true, ATOMIC = true,
  BEFORE = true, BINARY = true, BLOB = true, BOOLEAN = true, BREADTH = true,
  CALL = true, CALLED = true, CARDINALITY = true, CLASS = true, CLOB = true, COLLECT = true, COMPLETION = true,
  CONDITION = true, CONSTRUCTOR = true, CORR = true, COVAR_POP = true, COVAR_SAMP = true,
  CUBE = true, CUME_DIST = true, CURRENT_CATALOG = true, CURRENT_PATH = true, CURRENT_ROLE = true, CURRENT_SCHEMA = true, CYCLE = true,
  DATA = true, DEPTH = true, DEREF = true, DESTROY = true, DESTRUCTOR = true, DETERMINISTIC = true, DICTIONARY = true, DYNAMIC = true,
  EACH = true, ELEMENT = true, EQUALS = true, EVERY = true,
  FILTER = true, FREE = true, FULLTEXTTABLE = true, FUSION = true,
  GENERAL = true, GROUPING = true,
  HOLD = true, HOST = true,
  IGNORE = true, INITIALIZE = true, INOUT = true, INTERSECTION = true, ITERATE = true,
  LARGE = true, LATERAL = true, LESS = true, LIMIT = true, LN = true, LOCATOR = true,
  MAP = true, MEMBER = true, METHOD = true, MOD = true, MODIFIES = true, MODIFY = true, MULTISET = true,
  NCLOB = true, NEW = true, NORMALIZE = true,
  OBJECT = true, OLD = true, OPERATION = true, ORDINALITY = true, OVERLAY = true,
  PARAMETER = true, PARAMETERS = true, PARTITION = true, PATH = true, PERCENT_RANK = true,
  PERCENTILE_CONT = true, PERCENTILE_DISC = true,
  POSTFIX = true, PREFIX = true, PREORDER = true,
  RANGE = true, READS = true, RECURSIVE = true, REF = true, REFERENCING = true,
  REGR_AVGX = true, REGR_AVGY = true, REGR_COUNT = true, REGR_INTERCEPT = true, REGR_R2 = true,
  REGR_SLOPE = true, REGR_SXX = true, REGR_SXY = true, REGR_SYY = true,
  RELEASE = true, RESULT = true, RETURNS = true, ROLE = true, ROLLUP = true, ROUTINE = true, ROW = true,
  SAVEPOINT = true, SCOPE = true, SEARCH = true, SENSITIVE = true, SEQUENCE = true, SETS = true, SIMILAR = true,
  SPECIFIC = true, SPECIFICTYPE = true, SQLEXCEPTION = true, START = true, STATE = true, STATEMENT = true, STATIC = true,
  STDDEV_POP = true, STDDEV_SAMP = true, STRUCTURE = true, SUBMULTISET = true, SYMMETRIC = true, SYSTEM = true,
  TERMINATE = true, THAN = true, TREAT = true,
  UESCAPE = true, UNDER = true, UNNEST = true,
  VAR_POP = true, VAR_SAMP = true, VARIABLE = true,
  WIDTH_BUCKET = true, WINDOW = true, WITHOUT = true,
  XMLAGG = true, XMLATTRIBUTES = true, XMLBINARY = true, XMLCAST = true, XMLCOMMENT = true, XMLCONCAT = true,
  XMLDOCUMENT = true, XMLELEMENT = true, XMLEXISTS = true, XMLFOREST = true, XMLITERATE = true, XMLNAMESPACES = true,
  XMLPARSE = true, XMLPI = true, XMLQUERY = true, XMLSERIALIZE = true, XMLTABLE = true, XMLTEXT = true, XMLVALIDATE = true,

  -- ==========================================================================
  -- T-SQL Specific Keywords
  -- ==========================================================================
  APPLY = true, OPENJSON = true,
  TRY = true, CATCH = true, THROW = true,
  IIF = true, CHOOSE = true, GREATEST = true, LEAST = true,
  OFFSET = true, FIRST = true,
  UNBOUNDED = true, PRECEDING = true, FOLLOWING = true,

  -- ==========================================================================
  -- Control Flow
  -- ==========================================================================
  LOOP = true,

  -- ==========================================================================
  -- Cursor Keywords
  -- ==========================================================================
  KEYSET = true, FAST_FORWARD = true, READ_ONLY = true, SCROLL_LOCKS = true, OPTIMISTIC = true,

  -- ==========================================================================
  -- Table Hints
  -- ==========================================================================
  NOLOCK = true, READUNCOMMITTED = true, UPDLOCK = true, ROWLOCK = true, PAGLOCK = true, TABLOCK = true, TABLOCKX = true,
  READPAST = true, SERIALIZABLE = true, SNAPSHOT = true, READCOMMITTEDLOCK = true,
  FORCESEEK = true, FORCESCAN = true, NOEXPAND = true,
  XLOCK = true, NOWAIT = true,

  -- ==========================================================================
  -- Query Hints
  -- ==========================================================================
  RECOMPILE = true, MAXDOP = true, FAST = true, MAXRECURSION = true,
  EXPAND = true, VIEWS = true,

  -- ==========================================================================
  -- Data Types (used in CAST, CONVERT, variable declarations)
  -- ==========================================================================
  BIGINT = true, TINYINT = true, MONEY = true, SMALLMONEY = true,
  DATETIME = true, DATETIME2 = true, SMALLDATETIME = true, DATETIMEOFFSET = true,
  TEXT = true, NTEXT = true, IMAGE = true,
  NVARCHAR = true, VARBINARY = true,
  UNIQUEIDENTIFIER = true, XML = true, JSON = true,
  SQL_VARIANT = true, ROWVERSION = true,
  HIERARCHYID = true, GEOGRAPHY = true, GEOMETRY = true,

  -- ==========================================================================
  -- PostgreSQL Specific (for multi-database support)
  -- ==========================================================================
  RETURNING = true, ILIKE = true,

  -- ==========================================================================
  -- SQLite Specific (for multi-database support)
  -- ==========================================================================
  PRAGMA = true, VACUUM = true, ATTACH = true, DETACH = true, GLOB = true,
  TEMP = true,

  -- ==========================================================================
  -- MySQL Specific (for multi-database support)
  -- ==========================================================================
  UNSIGNED = true, ZEROFILL = true, AUTO_INCREMENT = true,
  EXPLAIN = true, SHOW = true, ANALYZE = true,
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

      -- Check for @ (variables/parameters)
      -- @ is only valid at start of identifier for variables (@var, @@system_var)
      -- If @ appears mid-identifier, it must be bracketed [col@name]
      elseif char == '@' then
        emit_single_char_token(char, TOKEN_TYPE.AT)
        col = col + 1
        i = i + 1

      -- Check for # (temp tables)
      -- # is only valid at start of identifier for temp tables (#temp, ##global)
      -- If # appears mid-identifier, it must be bracketed [Test#Table]
      elseif char == '#' then
        emit_single_char_token(char, TOKEN_TYPE.HASH)
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
