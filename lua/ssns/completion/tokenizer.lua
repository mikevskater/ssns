---@class Token
---@field type string TOKEN_TYPE value
---@field text string The token text
---@field line number 1-indexed line number
---@field col number 1-indexed column number
---@field keyword_category string? Keyword category: "statement", "clause", "function", "datatype", "operator", "constraint", "modifier", "misc"

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

-- ==========================================================================
-- SQL Keyword Categories for Granular Highlighting
-- Each category gets its own highlight group for user customization
-- ==========================================================================

-- Category 1: Statements (DML/DDL/Control Flow/Transaction)
local STATEMENT_KEYWORDS = {
  -- DML
  SELECT = true, INSERT = true, UPDATE = true, DELETE = true, MERGE = true,
  -- DDL
  CREATE = true, ALTER = true, DROP = true, TRUNCATE = true,
  -- Control flow
  IF = true, ELSE = true, WHILE = true, BEGIN = true, END = true,
  RETURN = true, BREAK = true, CONTINUE = true, GOTO = true, RETURNS = true,
  TRY = true, CATCH = true, THROW = true, LOOP = true,
  -- Transaction
  COMMIT = true, ROLLBACK = true, TRANSACTION = true, TRAN = true, SAVEPOINT = true,
  -- Execution
  EXEC = true, EXECUTE = true, DECLARE = true, SET = true, CALL = true,
  -- Other statements
  USE = true, PRINT = true, RAISERROR = true, WAITFOR = true,
  WITH = true, GO = true,
  -- Database management
  BACKUP = true, RESTORE = true, CHECKPOINT = true, DBCC = true,
  GRANT = true, REVOKE = true, DENY = true,
  -- Cursor operations
  OPEN = true, CLOSE = true, FETCH = true, DEALLOCATE = true,
  -- SQLite/PostgreSQL/MySQL specific
  PRAGMA = true, VACUUM = true, ATTACH = true, DETACH = true, EXPLAIN = true, SHOW = true, ANALYZE = true,
}

-- Category 2: Clauses
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
}

-- Category 3: Functions (Aggregate/Scalar/System)
local FUNCTION_KEYWORDS = {
  -- Aggregate
  COUNT = true, SUM = true, AVG = true, MIN = true, MAX = true,
  STRING_AGG = true, GROUPING = true, GROUPING_ID = true,
  STDEV = true, STDEVP = true, VAR = true, VARP = true,
  STDDEV_POP = true, STDDEV_SAMP = true, VAR_POP = true, VAR_SAMP = true,
  CORR = true, COVAR_POP = true, COVAR_SAMP = true,
  REGR_AVGX = true, REGR_AVGY = true, REGR_COUNT = true, REGR_INTERCEPT = true, REGR_R2 = true,
  REGR_SLOPE = true, REGR_SXX = true, REGR_SXY = true, REGR_SYY = true,
  PERCENTILE_CONT = true, PERCENTILE_DISC = true, PERCENT_RANK = true, CUME_DIST = true,
  -- String functions
  LEN = true, SUBSTRING = true, LTRIM = true, RTRIM = true, TRIM = true,
  UPPER = true, LOWER = true, REPLACE = true, STUFF = true,
  CHARINDEX = true, PATINDEX = true, CONCAT = true, CONCAT_WS = true,
  STRING_SPLIT = true, REVERSE = true, REPLICATE = true, SPACE = true, FORMAT = true,
  CHAR_LENGTH = true, CHARACTER_LENGTH = true, OCTET_LENGTH = true, BIT_LENGTH = true,
  TRANSLATE = true, POSITION = true, OVERLAY = true,
  -- Date/Time functions
  GETDATE = true, GETUTCDATE = true, SYSDATETIME = true,
  DATEADD = true, DATEDIFF = true, DATENAME = true, DATEPART = true,
  YEAR = true, MONTH = true, DAY = true, HOUR = true, MINUTE = true, SECOND = true,
  EOMONTH = true, DATEFROMPARTS = true, ISDATE = true, EXTRACT = true,
  LOCALTIME = true, LOCALTIMESTAMP = true,
  -- Conversion functions
  CAST = true, CONVERT = true, TRY_CAST = true, TRY_CONVERT = true, PARSE = true,
  -- NULL handling
  ISNULL = true, NULLIF = true, COALESCE = true, IIF = true, CHOOSE = true,
  GREATEST = true, LEAST = true,
  -- Math functions
  ABS = true, CEILING = true, FLOOR = true, ROUND = true,
  POWER = true, SQRT = true, SIGN = true, RAND = true, LN = true, MOD = true,
  WIDTH_BUCKET = true,
  -- System functions
  NEWID = true, NEWSEQUENTIALID = true,
  SCOPE_IDENTITY = true, IDENT_CURRENT = true,
  ROW_NUMBER = true, RANK = true, DENSE_RANK = true, NTILE = true,
  LAG = true, LEAD = true, FIRST_VALUE = true, LAST_VALUE = true,
  -- Type checking
  ISNUMERIC = true,
  -- Table functions
  OPENDATASOURCE = true, OPENQUERY = true, OPENROWSET = true, OPENXML = true, OPENJSON = true,
  CONTAINSTABLE = true, FREETEXTTABLE = true, SEMANTICKEYPHRASETABLE = true,
  SEMANTICSIMILARITYDETAILSTABLE = true, SEMANTICSIMILARITYTABLE = true, FULLTEXTTABLE = true,
  -- XML functions
  XMLAGG = true, XMLATTRIBUTES = true, XMLBINARY = true, XMLCAST = true, XMLCOMMENT = true, XMLCONCAT = true,
  XMLDOCUMENT = true, XMLELEMENT = true, XMLEXISTS = true, XMLFOREST = true, XMLITERATE = true, XMLNAMESPACES = true,
  XMLPARSE = true, XMLPI = true, XMLQUERY = true, XMLSERIALIZE = true, XMLTABLE = true, XMLTEXT = true, XMLVALIDATE = true,
  -- Cardinality/element
  CARDINALITY = true, ELEMENT = true, FUSION = true, COLLECT = true, MULTISET = true,
  SUBMULTISET = true, UNNEST = true, NORMALIZE = true,
}

-- Category 4: Data Types
local DATATYPE_KEYWORDS = {
  -- Numeric
  INT = true, INTEGER = true, BIGINT = true, SMALLINT = true, TINYINT = true,
  DECIMAL = true, NUMERIC = true, FLOAT = true, REAL = true, DOUBLE = true,
  MONEY = true, SMALLMONEY = true, BIT = true,
  -- String
  CHAR = true, VARCHAR = true, NCHAR = true, NVARCHAR = true,
  TEXT = true, NTEXT = true, CHARACTER = true,
  -- Binary
  BINARY = true, VARBINARY = true, IMAGE = true, BLOB = true, CLOB = true, NCLOB = true,
  -- Date/Time
  DATE = true, TIME = true, DATETIME = true, DATETIME2 = true,
  SMALLDATETIME = true, DATETIMEOFFSET = true, TIMESTAMP = true, INTERVAL = true,
  TIMEZONE_HOUR = true, TIMEZONE_MINUTE = true,
  -- DatePart
  YEAR = true, MONTH = true, WEEK = true, DAY = true, HOUR = true, MINUTE = true, 
  SECOND = true, MILLISECOND = true, DAYOFYEAR = true, ISO_WEEK = true, 
  MICROSECOND = true, NANOSECOND = true, QUARTER = true, TZOFFSET = true,  WEEKDAY = true,
  -- Other types
  UNIQUEIDENTIFIER = true, XML = true, JSON = true, SQL_VARIANT = true, ROWVERSION = true,
  GEOGRAPHY = true, GEOMETRY = true, HIERARCHYID = true,
  TABLE = true, CURSOR = true, BOOLEAN = true, ARRAY = true,
  -- Precision
  PRECISION = true, DEC = true,
  -- MySQL specific
  UNSIGNED = true, ZEROFILL = true, AUTO_INCREMENT = true,
}

-- Category 5: Operators/Logical
local OPERATOR_KEYWORDS = {
  AND = true, OR = true, NOT = true,
  IN = true, EXISTS = true, BETWEEN = true, LIKE = true, ILIKE = true, GLOB = true,
  IS = true, NULL = true, TRUE = true, FALSE = true,
  ANY = true, SOME = true,
  CONTAINS = true, FREETEXT = true, MATCH = true, SIMILAR = true,
  ESCAPE = true, OVERLAPS = true,
}

-- Category 6: Constraints/Index/Schema Definition
local CONSTRAINT_KEYWORDS = {
  PRIMARY = true, KEY = true, FOREIGN = true, REFERENCES = true,
  UNIQUE = true, CHECK = true, DEFAULT = true,
  CONSTRAINT = true, INDEX = true, CLUSTERED = true, NONCLUSTERED = true,
  IDENTITY = true, IDENTITY_INSERT = true, IDENTITYCOL = true, ROWGUIDCOL = true,
  CASCADE = true, RESTRICT = true, NOCHECK = true,
  ADD = true, COLUMN = true, MODIFY = true,
  -- Schema objects
  SCHEMA = true, DATABASE = true, VIEW = true, PROCEDURE = true, PROC = true,
  FUNCTION = true, TRIGGER = true, SEQUENCE = true, RULE = true,
  -- Storage
  FILLFACTOR = true, INCLUDE = true,
  -- Collation
  COLLATE = true, COLLATION = true,
}

-- Category 7: Modifiers/Hints
local MODIFIER_KEYWORDS = {
  ASC = true, DESC = true,
  -- Table hints
  NOLOCK = true, HOLDLOCK = true, UPDLOCK = true, READPAST = true,
  ROWLOCK = true, PAGLOCK = true, TABLOCK = true, TABLOCKX = true, XLOCK = true,
  READUNCOMMITTED = true, READCOMMITTEDLOCK = true, SERIALIZABLE = true, SNAPSHOT = true,
  FORCESEEK = true, FORCESCAN = true, NOEXPAND = true, NOWAIT = true,
  -- Query hints
  OPTION = true, MAXDOP = true, RECOMPILE = true, FAST = true, MAXRECURSION = true,
  EXPAND = true, OPTIMIZE = true, UNKNOWN = true,
  -- Window frame
  UNBOUNDED = true, PRECEDING = true, FOLLOWING = true, CURRENT = true, RANGE = true, WINDOW = true,
  -- Cursor options
  SCROLL = true, INSENSITIVE = true, KEYSET = true, FAST_FORWARD = true, READ_ONLY = true,
  SCROLL_LOCKS = true, OPTIMISTIC = true, DYNAMIC = true, STATIC = true, FORWARD_ONLY = true,
  -- Other modifiers
  PERCENT = true, TABLESAMPLE = true, RECURSIVE = true,
  LATERAL = true, VARYING = true, EXTERNAL = true, TEMP = true, TEMPORARY = true, LOCAL = true, GLOBAL = true,
}

-- Category 8: Miscellaneous (reserved words that don't fit other categories)
local MISC_KEYWORDS = {
  -- Session/user context
  CURRENT_DATE = true, CURRENT_TIME = true, CURRENT_TIMESTAMP = true, CURRENT_USER = true,
  SESSION_USER = true, SYSTEM_USER = true, USER = true,
  CURRENT_CATALOG = true, CURRENT_PATH = true, CURRENT_ROLE = true, CURRENT_SCHEMA = true,
  -- Reserved identifiers and special keywords
  AUTHORIZATION = true, PUBLIC = true, ROLE = true, ADMIN = true, PRIVILEGES = true, USAGE = true,
  -- Other reserved
  BROWSE = true, BULK = true, COMPUTE = true, DISK = true, DISTRIBUTED = true, DUMP = true,
  ERRLVL = true, EXIT = true, FILE = true, KILL = true, LABEL = true, LINENO = true, LOAD = true,
  NATIONAL = true, OF = true, OFF = true, OFFSETS = true, PLAN = true, READ = true, READTEXT = true,
  RECONFIGURE = true, REPLICATION = true, REVERT = true, ROWCOUNT = true, SAVE = true,
  SECURITYAUDIT = true, SETUSER = true, SHUTDOWN = true, STATISTICS = true, TEXTSIZE = true, TO = true,
  TSEQUAL = true, UPDATETEXT = true, WITHIN = true, WRITETEXT = true,
  -- Transaction isolation
  ISOLATION = true, LEVEL = true, WORK = true, SESSION = true, CONNECTION = true,
  -- Future reserved
  ABSOLUTE = true, ACTION = true, AFTER = true, AGGREGATE = true, ALIAS = true, ALLOCATE = true,
  ARE = true, ASENSITIVE = true, ASSERTION = true, ASYMMETRIC = true, AT = true, ATOMIC = true, BEFORE = true,
  BOTH = true, BREADTH = true, CALLED = true, CASCADED = true, CATALOG = true, CLASS = true, COMPLETION = true,
  CONDITION = true, CONSTRUCTOR = true, CORRESPONDING = true, CUBE = true, CYCLE = true, DATA = true,
  DEFERRABLE = true, DEFERRED = true, DEPTH = true, DEREF = true, DESCRIBE = true, DESCRIPTOR = true,
  DESTROY = true, DESTRUCTOR = true, DETERMINISTIC = true, DIAGNOSTICS = true, DICTIONARY = true, DISCONNECT = true,
  DOMAIN = true, EACH = true, EQUALS = true, EVERY = true, EXCEPTION = true, FILTER = true, FIRST = true,
  FOUND = true, FREE = true, GENERAL = true, GET = true, HOLD = true, HOST = true, IGNORE = true,
  IMMEDIATE = true, INDICATOR = true, INITIALIZE = true, INITIALLY = true, INOUT = true, INPUT = true,
  INTERSECTION = true, ITERATE = true, LANGUAGE = true, LARGE = true, LAST = true, LEADING = true, LESS = true,
  LOCATOR = true, MAP = true, MEMBER = true, METHOD = true, MODIFIES = true, MODULE = true, NAMES = true,
  NEW = true, NEXT = true, NO = true, NONE = true, OBJECT = true, OLD = true, OPERATION = true,
  ORDINALITY = true, PAD = true, PARAMETER = true, PARAMETERS = true, PARTIAL = true, PATH = true, POSTFIX = true,
  PREFIX = true, PREORDER = true, PREPARE = true, PRESERVE = true, PRIOR = true, READS = true, REF = true,
  REFERENCING = true, RELATIVE = true, RELEASE = true, RESULT = true, RETURNS = true, ROLLUP = true, ROUTINE = true,
  ROW = true, SCOPE = true, SEARCH = true, SECTION = true, SENSITIVE = true, SETS = true, SIZE = true,
  SPECIFIC = true, SPECIFICTYPE = true, SQLCA = true, SQLCODE = true, SQLERROR = true, SQLEXCEPTION = true,
  SQLSTATE = true, SQLWARNING = true, SQL = true, START = true, STATE = true, STATEMENT = true,
  STRUCTURE = true, SYMMETRIC = true, SYSTEM = true, TERMINATE = true, THAN = true, TRAILING = true,
  TRANSLATE_REGEX = true, TREAT = true, UNDER = true, UESCAPE = true, VALUE = true, VARIABLE = true,
  VIEWS = true, WHENEVER = true, WITHOUT = true, WRITE = true, ZONE = true, CONNECT = true, CONSTRAINTS = true,
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
    -- First category wins for duplicates (priority: statement > clause > function > datatype > operator > constraint > modifier > misc)
    if not KEYWORD_TO_CATEGORY[keyword] then
      KEYWORD_TO_CATEGORY[keyword] = cat.category
    end
  end
end

-- Build flat lookup table for backwards compatibility
local SQL_KEYWORDS = {}
for keyword, _ in pairs(KEYWORD_TO_CATEGORY) do
  SQL_KEYWORDS[keyword] = true
end

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
    local keyword_category = nil

    if not token_type then
      -- Determine token type based on content
      if is_keyword(current_token) then
        local upper = current_token:upper()
        -- Check for GO keyword (must be alone on line conceptually)
        if upper == "GO" then
          token_type = TOKEN_TYPE.GO
          keyword_category = "statement"  -- GO is a batch separator/statement
        else
          token_type = TOKEN_TYPE.KEYWORD
          keyword_category = KEYWORD_TO_CATEGORY[upper]
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
      keyword_category = keyword_category,
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
      -- Check for escaped quote ''
      if char == "'" and next_char == "'" then
        current_token = current_token .. "''"
        col = col + 2
        i = i + 2
      elseif char == "'" then
        -- End of string
        current_token = current_token .. char
        emit_token(TOKEN_TYPE.STRING)
        state = STATE.NORMAL
        col = col + 1
        i = i + 1
      else
        -- Handle newlines within strings
        current_token = current_token .. char
        if char == '\n' then
          line = line + 1
          col = 1
          i = i + 1
        elseif char == '\r' then
          -- Handle \r\n or \r alone
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
