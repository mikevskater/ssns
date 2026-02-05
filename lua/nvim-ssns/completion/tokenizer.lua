---@class Token
---@field type string TOKEN_TYPE value
---@field text string The token text
---@field line number 1-indexed line number
---@field col number 1-indexed column number
---@field keyword_category string? Keyword category: "statement", "clause", "function", "datatype", "operator", "constraint", "modifier", "misc", "global_variable", "system_procedure"

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
  AT = "at",                   -- @ alone (rare, kept for backwards compatibility)
  VARIABLE = "variable",       -- @var user variables/parameters (@UserId, @variable)
  GLOBAL_VARIABLE = "global_variable", -- @@ for system variables (@@ROWCOUNT, @@VERSION)
  SYSTEM_PROCEDURE = "system_procedure", -- sp_*, xp_* system stored procedures
  TEMP_TABLE = "temp_table",   -- #temp or ##global temp tables (full name)
  HASH = "hash",               -- # for other uses (rarely needed now)
  COMMENT = "comment",         -- Block comments /* ... */
  LINE_COMMENT = "line_comment", -- Line comments -- ...
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
  -- MERGE clause keyword
  MATCHED = true,
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

-- Category 9: Global Variables (@@SERVERNAME, @@VERSION, @@ROWCOUNT, etc.)
-- These are SQL Server system functions/variables that start with @@
local GLOBAL_VARIABLE_KEYWORDS = {
  -- Server configuration
  SERVERNAME = true, SERVICENAME = true, VERSION = true, LANGUAGE = true, LANGID = true,
  MAX_CONNECTIONS = true, MAX_PRECISION = true, MICROSOFTVERSION = true,
  -- Error and row handling
  ROWCOUNT = true, ERROR = true, TRANCOUNT = true,
  -- Identity
  IDENTITY = true,
  -- Cursor
  FETCH_STATUS = true, CURSOR_ROWS = true,
  -- Date/Time configuration
  DATEFIRST = true, DBTS = true,
  -- Server statistics
  CONNECTIONS = true, CPU_BUSY = true, IDLE = true, IO_BUSY = true,
  PACKET_ERRORS = true, PACK_RECEIVED = true, PACK_SENT = true,
  TOTAL_ERRORS = true, TOTAL_READ = true, TOTAL_WRITE = true, TIMETICKS = true,
  -- Session
  NESTLEVEL = true, OPTIONS = true, PROCID = true, SPID = true, TEXTSIZE = true,
  LOCK_TIMEOUT = true, DEF_SORTORDER_ID = true,
  -- Replication
  REPLICATION = true,
}

-- Category 10: System Stored Procedures (sp_*, xp_*)
-- Common SQL Server system stored procedures for metadata, help, and administration
local SYSTEM_PROCEDURE_KEYWORDS = {
  -- Help and metadata procedures
  sp_help = true, sp_helptext = true, sp_helpdb = true, sp_helpindex = true,
  sp_helpconstraint = true, sp_helptrigger = true, sp_helpfile = true,
  sp_helpfilegroup = true, sp_helplanguage = true, sp_helpserver = true,
  sp_helpsort = true, sp_helpstats = true, sp_helpextendedproc = true,
  sp_helprole = true, sp_helprolemember = true, sp_helpsrvrole = true,
  sp_helpsrvrolemember = true, sp_helpuser = true, sp_helpremotelogin = true,
  sp_helplinkedsrvlogin = true, sp_helpntgroup = true, sp_helplogins = true,
  sp_helpsubscriberinfo = true, sp_helppublication = true, sp_helparticle = true,
  -- Catalog procedures
  sp_columns = true, sp_tables = true, sp_stored_procedures = true,
  sp_databases = true, sp_fkeys = true, sp_pkeys = true, sp_server_info = true,
  sp_special_columns = true, sp_sproc_columns = true, sp_statistics = true,
  sp_table_privileges = true, sp_column_privileges = true, sp_datatype_info = true,
  -- User and security procedures
  sp_addlogin = true, sp_droplogin = true, sp_password = true, sp_defaultdb = true,
  sp_defaultlanguage = true, sp_adduser = true, sp_dropuser = true, sp_grantdbaccess = true,
  sp_revokedbaccess = true, sp_addrolemember = true, sp_droprolemember = true,
  sp_addrole = true, sp_droprole = true, sp_addsrvrolemember = true, sp_dropsrvrolemember = true,
  sp_grantlogin = true, sp_revokelogin = true, sp_denylogin = true, sp_change_users_login = true,
  sp_validatelogins = true, sp_helprotect = true, sp_addlinkedsrvlogin = true,
  sp_droplinkedsrvlogin = true, sp_addremotelogin = true, sp_dropremotelogin = true,
  -- Database procedures
  sp_dboption = true, sp_renamedb = true, sp_detach_db = true, sp_attach_db = true,
  sp_attach_single_file_db = true, sp_certify_removable = true, sp_create_removable = true,
  sp_dbcmptlevel = true, sp_helpdevice = true, sp_addumpdevice = true, sp_dropdevice = true,
  sp_dbfixedrolepermission = true,
  -- Object procedures
  sp_rename = true, sp_renameobject = true, sp_depends = true, sp_spaceused = true,
  sp_executesql = true, sp_refreshview = true, sp_recompile = true, sp_autostats = true,
  sp_createstats = true, sp_updatestats = true, sp_unbindefault = true, sp_bindefault = true,
  sp_unbindrule = true, sp_bindrule = true, sp_addtype = true, sp_droptype = true,
  sp_addmessage = true, sp_altermessage = true, sp_dropmessage = true,
  -- Linked server procedures
  sp_addlinkedserver = true, sp_droplinkedserver = true, sp_linkedservers = true,
  sp_serveroption = true, sp_setnetname = true, sp_addserver = true, sp_dropserver = true,
  sp_helpsubscription = true, sp_testlinkedserver = true,
  -- Replication procedures
  sp_addpublication = true, sp_droppublication = true, sp_addarticle = true, sp_droparticle = true,
  sp_addsubscription = true, sp_dropsubscription = true, sp_addsubscriber = true,
  sp_dropsubscriber = true, sp_addpullsubscription = true, sp_droppullsubscription = true,
  sp_changemergepublication = true, sp_changemergearticle = true, sp_changemergesubscription = true,
  sp_addmergepublication = true, sp_dropmergepublication = true, sp_addmergearticle = true,
  sp_dropmergearticle = true, sp_addmergesubscription = true, sp_dropmergesubscription = true,
  sp_replcmds = true, sp_replcounters = true, sp_repldone = true, sp_replflush = true,
  sp_repltrans = true, sp_publication_validation = true, sp_article_validation = true,
  -- Job and agent procedures
  sp_add_job = true, sp_delete_job = true, sp_update_job = true, sp_start_job = true,
  sp_stop_job = true, sp_add_jobstep = true, sp_delete_jobstep = true, sp_update_jobstep = true,
  sp_add_jobschedule = true, sp_delete_jobschedule = true, sp_update_jobschedule = true,
  sp_add_schedule = true, sp_delete_schedule = true, sp_attach_schedule = true,
  sp_detach_schedule = true, sp_add_jobserver = true, sp_delete_jobserver = true,
  sp_add_operator = true, sp_delete_operator = true, sp_update_operator = true,
  sp_add_alert = true, sp_delete_alert = true, sp_update_alert = true,
  sp_add_notification = true, sp_delete_notification = true, sp_update_notification = true,
  sp_add_category = true, sp_delete_category = true, sp_update_category = true,
  sp_help_job = true, sp_help_jobstep = true, sp_help_jobschedule = true,
  sp_help_operator = true, sp_help_alert = true, sp_help_notification = true,
  sp_help_category = true, sp_help_jobhistory = true, sp_purge_jobhistory = true,
  -- Maintenance procedures
  sp_cycle_errorlog = true, sp_readerrorlog = true, sp_who = true, sp_who2 = true,
  sp_lock = true, sp_monitor = true, sp_configure = true, sp_procoption = true,
  sp_trace_create = true, sp_trace_setevent = true, sp_trace_setfilter = true,
  sp_trace_setstatus = true, sp_trace_generateevent = true,
  -- XML procedures
  sp_xml_preparedocument = true, sp_xml_removedocument = true,
  -- Full-text search procedures
  sp_fulltext_database = true, sp_fulltext_catalog = true, sp_fulltext_table = true,
  sp_fulltext_column = true, sp_fulltext_service = true, sp_help_fulltext_catalogs = true,
  sp_help_fulltext_tables = true, sp_help_fulltext_columns = true,
  sp_help_fulltext_catalogs_cursor = true, sp_help_fulltext_tables_cursor = true,
  sp_help_fulltext_columns_cursor = true,
  -- Cursor procedures
  sp_cursor = true, sp_cursor_list = true, sp_cursoropen = true, sp_cursorfetch = true,
  sp_cursorclose = true, sp_cursoroption = true, sp_cursorprepare = true,
  sp_cursorexecute = true, sp_cursorunprepare = true, sp_cursorprepexec = true,
  sp_describe_cursor = true, sp_describe_cursor_columns = true, sp_describe_cursor_tables = true,
  -- OLE Automation procedures
  sp_OACreate = true, sp_OADestroy = true, sp_OAGetErrorInfo = true, sp_OAGetProperty = true,
  sp_OAMethod = true, sp_OASetProperty = true, sp_OAStop = true,
  -- Extended stored procedures (xp_*)
  xp_cmdshell = true, xp_msver = true, xp_sprintf = true, xp_sscanf = true,
  xp_loginconfig = true, xp_logininfo = true, xp_grantlogin = true, xp_revokelogin = true,
  xp_logevent = true, xp_instance_regread = true, xp_instance_regwrite = true,
  xp_regread = true, xp_regwrite = true, xp_regdelete = true, xp_regenumkeys = true,
  xp_regenumvalues = true, xp_regaddmultistring = true, xp_regremovemultistring = true,
  xp_fileexist = true, xp_fixeddrives = true, xp_subdirs = true, xp_dirtree = true,
  xp_create_subdir = true, xp_delete_file = true, xp_getfiledetails = true,
  xp_availablemedia = true, xp_enumdsn = true, xp_enumerrorlogs = true,
  xp_getnetname = true, xp_readerrorlog = true, xp_servicecontrol = true,
  xp_sqlagent_enum_jobs = true, xp_sqlagent_is_starting = true, xp_sqlagent_notify = true,
  xp_sendmail = true, xp_startmail = true, xp_stopmail = true, xp_deletemail = true,
  xp_findnextmsg = true, xp_readmail = true,
  -- DBCC commands (treated as system procedures)
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
  local last_token_type = nil  -- Track last emitted token for negative number detection

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
      elseif current_token:match("^%-?%d+%.?%d*$") or current_token:match("^%-?%d*%.%d+$") or current_token:match("^%-?0[xX][0-9a-fA-F]+$") then
        -- Number detection: integer, decimal, negative, or hex (0x4E)
        token_type = TOKEN_TYPE.NUMBER
      elseif SYSTEM_PROCEDURE_KEYWORDS[current_token] or SYSTEM_PROCEDURE_KEYWORDS[current_token:lower()] then
        -- System stored procedure (sp_*, xp_*, DBCC)
        token_type = TOKEN_TYPE.SYSTEM_PROCEDURE
        keyword_category = "system_procedure"
      else
        token_type = TOKEN_TYPE.IDENTIFIER
      end
    elseif token_type == TOKEN_TYPE.GLOBAL_VARIABLE then
      -- Set keyword_category for global variables (@@ROWCOUNT, @@VERSION, etc.)
      keyword_category = "global_variable"
    elseif token_type == TOKEN_TYPE.SYSTEM_PROCEDURE then
      -- Set keyword_category for system procedures (sp_*, xp_*)
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
      -- Handle N'unicode string' prefix - include N with the string
      elseif char == "'" then
        -- Check if current accumulated token is just 'N' or 'n' (Unicode string prefix)
        if current_token:upper() == "N" then
          -- Include the N prefix with the string
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
        start_token()  -- Track start position for comment token
        current_token = "/*"  -- Start accumulating with delimiter
        state = STATE.IN_BLOCK_COMMENT
        comment_depth = 1
        col = col + 2
        i = i + 2

      -- Check for line comment start --
      elseif char == '-' and next_char == '-' then
        emit_token()
        start_token()  -- Track start position for comment token
        current_token = "--"  -- Start accumulating with delimiter
        state = STATE.IN_LINE_COMMENT
        col = col + 2
        i = i + 2

      -- Check for star (special - used for SELECT *)
      elseif char == '*' then
        emit_single_char_token(char, TOKEN_TYPE.STAR)
        col = col + 1
        i = i + 1

      -- Check for negative number: - followed by digit(s)
      -- Only treat as negative number in contexts where subtraction doesn't make sense
      elseif char == '-' and next_char and (next_char:match("%d") or (next_char == '.' and peek(text, i + 1) and peek(text, i + 1):match("%d"))) then
        -- Check context: negative number if after operator, comma, open paren, keyword, or at start
        local is_negative_number_context = (
          last_token_type == nil or  -- Start of input
          last_token_type == TOKEN_TYPE.OPERATOR or
          last_token_type == TOKEN_TYPE.COMMA or
          last_token_type == TOKEN_TYPE.PAREN_OPEN or
          last_token_type == TOKEN_TYPE.KEYWORD or
          last_token_type == TOKEN_TYPE.GO or
          last_token_type == TOKEN_TYPE.SEMICOLON
        )

        if is_negative_number_context and current_token == "" then
          -- Consume as negative number
          start_token()
          current_token = "-"
          col = col + 1
          i = i + 1
          -- The digits will be accumulated by the normal character loop
        else
          -- Treat as subtraction operator
          emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
          col = col + 1
          i = i + 1
        end

      -- Check for multi-character and single-character operators
      elseif SINGLE_CHAR_OPERATORS[char] then
        -- Check for multi-character operators: <>, <=, >=, !=, ::
        if char == '<' and next_char then
          if next_char == '>' then
            -- <> (not equal)
            emit_single_char_token('<>', TOKEN_TYPE.OPERATOR)
            col = col + 2
            i = i + 2
          elseif next_char == '=' then
            -- <=
            emit_single_char_token('<=', TOKEN_TYPE.OPERATOR)
            col = col + 2
            i = i + 2
          else
            emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
            col = col + 1
            i = i + 1
          end
        elseif char == '>' and next_char and next_char == '=' then
          -- >=
          emit_single_char_token('>=', TOKEN_TYPE.OPERATOR)
          col = col + 2
          i = i + 2
        elseif char == '!' and next_char and next_char == '=' then
          -- !=
          emit_single_char_token('!=', TOKEN_TYPE.OPERATOR)
          col = col + 2
          i = i + 2
        elseif char == ':' and next_char and next_char == ':' then
          -- :: (PostgreSQL cast operator)
          emit_single_char_token('::', TOKEN_TYPE.OPERATOR)
          col = col + 2
          i = i + 2
        else
          emit_single_char_token(char, TOKEN_TYPE.OPERATOR)
          col = col + 1
          i = i + 1
        end

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
        -- Check if this is part of a decimal number:
        -- 1. Current token is all digits AND next char is a digit (123.45)
        -- 2. Current token is empty AND next char is a digit (.45)
        -- 3. Current token is negative number (-12) AND next char is a digit (-12.34)
        local is_decimal_number = false
        if next_char and next_char:match("%d") then
          if current_token == "" or current_token:match("^%-?%d+$") then
            is_decimal_number = true
          end
        end

        if is_decimal_number then
          -- Include dot in the number token
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

      -- Check for @ (variables/parameters) and @@ (global variables)
      -- @ followed by identifier is a user variable (@var, @UserId)
      -- @@ is for system/global variables (@@ROWCOUNT, @@VERSION)
      -- If @ appears mid-identifier, it must be bracketed [col@name]
      elseif char == '@' then
        emit_token() -- Emit any accumulated token first
        start_token()
        -- Check for @@ (global variable)
        if next_char == '@' then
          -- Consume both @@ and the following identifier
          local global_var = "@@"
          local j = i + 2
          -- Collect the identifier part
          while j <= #text do
            local c = text:sub(j, j)
            if is_alnum(c) then
              global_var = global_var .. c
              j = j + 1
            else
              break
            end
          end
          -- Check if the identifier part (without @@) is a known global variable
          local var_name = global_var:sub(3):upper()
          current_token = global_var
          if GLOBAL_VARIABLE_KEYWORDS[var_name] then
            emit_token(TOKEN_TYPE.GLOBAL_VARIABLE)
          else
            -- Unknown @@variable, still emit as GLOBAL_VARIABLE for highlighting
            emit_token(TOKEN_TYPE.GLOBAL_VARIABLE)
          end
          col = col + #global_var
          i = j
        elseif next_char and is_alnum(next_char) then
          -- Single @ followed by identifier is a user variable (@var, @UserId)
          local user_var = "@"
          local j = i + 1
          -- Collect the identifier part
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
          -- Lone @ with no identifier following (rare edge case)
          emit_single_char_token(char, TOKEN_TYPE.AT)
          col = col + 1
          i = i + 1
        end

      -- Check for # (temp tables)
      -- Consume the entire temp table name: #temp or ##global_temp
      -- If # appears mid-identifier, it must be bracketed [Test#Table]
      elseif char == '#' then
        emit_token() -- Emit any accumulated token first
        start_token()
        -- Consume # or ##
        local temp_table = "#"
        local j = i + 1
        -- Check for ## (global temp table)
        if j <= #text and text:sub(j, j) == '#' then
          temp_table = "##"
          j = j + 1
        end
        -- Collect the identifier part
        while j <= #text do
          local c = text:sub(j, j)
          if is_alnum(c) then
            temp_table = temp_table .. c
            j = j + 1
          else
            break
          end
        end
        -- Only emit as TEMP_TABLE if we have an identifier after #
        if #temp_table > 1 and (temp_table:sub(2, 2) ~= '#' or #temp_table > 2) then
          current_token = temp_table
          emit_token(TOKEN_TYPE.TEMP_TABLE)
        else
          -- Just a lone # or ##, emit as HASH
          current_token = temp_table
          emit_token(TOKEN_TYPE.HASH)
        end
        col = col + #temp_table
        i = j

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
        current_token = current_token .. "/*"  -- Accumulate nested delimiter
        col = col + 2
        i = i + 2
      -- Check for comment end */
      elseif char == '*' and next_char == '/' then
        comment_depth = comment_depth - 1
        current_token = current_token .. "*/"  -- Accumulate closing delimiter
        col = col + 2
        i = i + 2
        if comment_depth == 0 then
          emit_token(TOKEN_TYPE.COMMENT)  -- Emit complete comment token
          state = STATE.NORMAL
        end
      else
        -- Accumulate content and track line/col for newlines in comments
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
        -- End of line comment - emit token (excludes newline)
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
        -- Accumulate comment content
        current_token = current_token .. char
        col = col + 1
        i = i + 1
      end
    end
  end

  -- Handle EOF cases for comment states
  if state == STATE.IN_LINE_COMMENT and current_token ~= "" then
    -- Line comment reaches EOF without newline
    emit_token(TOKEN_TYPE.LINE_COMMENT)
  elseif state == STATE.IN_BLOCK_COMMENT and current_token ~= "" then
    -- Unclosed block comment - emit what we have (for highlighting)
    emit_token(TOKEN_TYPE.COMMENT)
  else
    -- Emit any remaining token
    emit_token()
  end

  return tokens
end

---@class TokenizeAsyncOpts
---@field on_progress fun(pct: number, message: string?)? Progress callback (percentage-based)
---@field on_complete fun(tokens: Token[])? Completion callback (required)

---Active async tokenize task ID
---@type string?
Tokenizer._async_task_id = nil

---Tokenize SQL text asynchronously using threaded worker
---Falls back to synchronous tokenization if threading unavailable
---@param text string The SQL text to tokenize
---@param opts TokenizeAsyncOpts Options for async tokenization
function Tokenizer.tokenize_async(text, opts)
  opts = opts or {}
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete

  if not text or text == "" then
    if on_progress then on_progress(100, "Complete") end
    if on_complete then on_complete({}) end
    return
  end

  -- Cancel any existing async tokenize
  Tokenizer.cancel_async_tokenize()

  -- Try to use threaded worker
  local Coordinator = require('nvim-ssns.async.thread.coordinator')

  if not Coordinator.is_available() then
    -- Fall back to sync tokenize
    local tokens = Tokenizer.tokenize(text)
    if on_progress then on_progress(100, "Complete") end
    if on_complete then on_complete(tokens) end
    return
  end

  -- Start threaded tokenization
  local task_id, err = Coordinator.start({
    worker = "tokenize",
    input = {
      text = text,
      options = {
        progress_interval = 10,
      },
    },
    on_progress = function(pct, message)
      if on_progress then
        on_progress(pct, message)
      end
    end,
    on_complete = function(result, error_msg)
      -- Clear active task
      Tokenizer._async_task_id = nil

      if error_msg then
        -- Fall back to sync on error
        vim.schedule(function()
          local tokens = Tokenizer.tokenize(text)
          if on_complete then on_complete(tokens) end
        end)
      elseif result and result.tokens then
        if on_complete then on_complete(result.tokens) end
      elseif result and result.cancelled then
        -- Cancelled, don't call callback
      else
        -- No tokens returned, fall back to sync
        vim.schedule(function()
          local tokens = Tokenizer.tokenize(text)
          if on_complete then on_complete(tokens) end
        end)
      end
    end,
    timeout_ms = 60000, -- 60 second timeout for large files
  })

  if not task_id then
    -- Fall back to sync tokenize on startup failure
    local tokens = Tokenizer.tokenize(text)
    if on_progress then on_progress(100, "Complete") end
    if on_complete then on_complete(tokens) end
    return
  end

  Tokenizer._async_task_id = task_id
end

---Cancel any in-progress async tokenization
function Tokenizer.cancel_async_tokenize()
  if Tokenizer._async_task_id then
    local Coordinator = require('nvim-ssns.async.thread.coordinator')
    Coordinator.cancel(Tokenizer._async_task_id, "Cancelled")
    Tokenizer._async_task_id = nil
  end
end

---Check if async tokenization is currently in progress
---@return boolean
function Tokenizer.is_async_tokenize_active()
  return Tokenizer._async_task_id ~= nil
end

return Tokenizer
