---SQL Server built-in function definitions for completion
---Comprehensive list from Microsoft documentation
---Source: https://learn.microsoft.com/en-us/sql/t-sql/functions/functions
---@class FunctionsData
local Functions = {}

---@class FunctionDefinition
---@field name string Function name
---@field signature string Function signature with parameters
---@field description string Brief description
---@field category string Function category
---@field returns string? Return type

-- =============================================================================
-- Aggregate Functions
-- =============================================================================
Functions.aggregate = {
  { name = "APPROX_COUNT_DISTINCT", signature = "APPROX_COUNT_DISTINCT(expression)", description = "Returns approximate count of unique non-null values", returns = "bigint" },
  { name = "AVG", signature = "AVG([ALL | DISTINCT] expression)", description = "Returns average of values in expression", returns = "numeric" },
  { name = "CHECKSUM_AGG", signature = "CHECKSUM_AGG([ALL | DISTINCT] expression)", description = "Returns checksum of values in a group", returns = "int" },
  { name = "COUNT", signature = "COUNT([ALL | DISTINCT] expression | *)", description = "Returns number of items in a group", returns = "int" },
  { name = "COUNT_BIG", signature = "COUNT_BIG([ALL | DISTINCT] expression | *)", description = "Returns number of items (bigint)", returns = "bigint" },
  { name = "GROUPING", signature = "GROUPING(column_expression)", description = "Indicates whether expression is aggregated", returns = "tinyint" },
  { name = "GROUPING_ID", signature = "GROUPING_ID(column_expression [, ...])", description = "Returns level of grouping", returns = "int" },
  { name = "MAX", signature = "MAX([ALL | DISTINCT] expression)", description = "Returns maximum value", returns = "varies" },
  { name = "MIN", signature = "MIN([ALL | DISTINCT] expression)", description = "Returns minimum value", returns = "varies" },
  { name = "STDEV", signature = "STDEV([ALL | DISTINCT] expression)", description = "Returns statistical standard deviation (sample)", returns = "float" },
  { name = "STDEVP", signature = "STDEVP([ALL | DISTINCT] expression)", description = "Returns statistical standard deviation (population)", returns = "float" },
  { name = "STRING_AGG", signature = "STRING_AGG(expression, separator) [WITHIN GROUP (ORDER BY ...)]", description = "Concatenates string values with separator", returns = "nvarchar(max)" },
  { name = "SUM", signature = "SUM([ALL | DISTINCT] expression)", description = "Returns sum of values", returns = "numeric" },
  { name = "VAR", signature = "VAR([ALL | DISTINCT] expression)", description = "Returns statistical variance (sample)", returns = "float" },
  { name = "VARP", signature = "VARP([ALL | DISTINCT] expression)", description = "Returns statistical variance (population)", returns = "float" },
}

-- =============================================================================
-- String Functions
-- =============================================================================
Functions.string = {
  { name = "ASCII", signature = "ASCII(character_expression)", description = "Returns ASCII code of leftmost character", returns = "int" },
  { name = "CHAR", signature = "CHAR(integer_expression)", description = "Converts ASCII code to character", returns = "char(1)" },
  { name = "CHARINDEX", signature = "CHARINDEX(substring, string [, start_location])", description = "Returns position of substring in string", returns = "int" },
  { name = "CONCAT", signature = "CONCAT(string1, string2 [, stringN])", description = "Concatenates strings together", returns = "varchar/nvarchar" },
  { name = "CONCAT_WS", signature = "CONCAT_WS(separator, string1, string2 [, stringN])", description = "Concatenates strings with separator", returns = "varchar/nvarchar" },
  { name = "DIFFERENCE", signature = "DIFFERENCE(string1, string2)", description = "Returns SOUNDEX difference between strings", returns = "int" },
  { name = "FORMAT", signature = "FORMAT(value, format [, culture])", description = "Returns formatted value using .NET format string", returns = "nvarchar" },
  { name = "LEFT", signature = "LEFT(string, count)", description = "Returns leftmost characters of string", returns = "varchar/nvarchar" },
  { name = "LEN", signature = "LEN(string_expression)", description = "Returns length of string (excluding trailing spaces)", returns = "int/bigint" },
  { name = "LOWER", signature = "LOWER(character_expression)", description = "Converts string to lowercase", returns = "varchar/nvarchar" },
  { name = "LTRIM", signature = "LTRIM(character_expression)", description = "Removes leading spaces", returns = "varchar/nvarchar" },
  { name = "NCHAR", signature = "NCHAR(integer_expression)", description = "Returns Unicode character for code", returns = "nchar(1)" },
  { name = "PATINDEX", signature = "PATINDEX('%pattern%', expression)", description = "Returns starting position of pattern", returns = "bigint" },
  { name = "QUOTENAME", signature = "QUOTENAME(string [, quote_character])", description = "Returns string with delimiters for valid identifier", returns = "nvarchar(258)" },
  { name = "REPLACE", signature = "REPLACE(string, pattern, replacement)", description = "Replaces all occurrences of pattern", returns = "varchar/nvarchar" },
  { name = "REPLICATE", signature = "REPLICATE(string, count)", description = "Repeats string specified number of times", returns = "varchar/nvarchar" },
  { name = "REVERSE", signature = "REVERSE(string_expression)", description = "Reverses string character order", returns = "varchar/nvarchar" },
  { name = "RIGHT", signature = "RIGHT(string, count)", description = "Returns rightmost characters of string", returns = "varchar/nvarchar" },
  { name = "RTRIM", signature = "RTRIM(character_expression)", description = "Removes trailing spaces", returns = "varchar/nvarchar" },
  { name = "SOUNDEX", signature = "SOUNDEX(character_expression)", description = "Returns phonetic (SOUNDEX) code", returns = "varchar(4)" },
  { name = "SPACE", signature = "SPACE(count)", description = "Returns string of repeated spaces", returns = "varchar" },
  { name = "STR", signature = "STR(float_expression [, length [, decimal]])", description = "Converts numeric to character string", returns = "varchar" },
  { name = "STRING_ESCAPE", signature = "STRING_ESCAPE(text, type)", description = "Escapes special characters", returns = "nvarchar(max)" },
  { name = "STRING_SPLIT", signature = "STRING_SPLIT(string, separator [, enable_ordinal])", description = "Splits string by delimiter into rows", returns = "table" },
  { name = "STUFF", signature = "STUFF(string, start, length, insert_string)", description = "Deletes and inserts characters at position", returns = "varchar/nvarchar" },
  { name = "SUBSTRING", signature = "SUBSTRING(expression, start, length)", description = "Returns part of string", returns = "varchar/nvarchar" },
  { name = "TRANSLATE", signature = "TRANSLATE(inputString, characters, translations)", description = "Replaces characters with mapped translations", returns = "varchar/nvarchar" },
  { name = "TRIM", signature = "TRIM([characters FROM] string)", description = "Removes leading/trailing spaces or characters", returns = "varchar/nvarchar" },
  { name = "UNICODE", signature = "UNICODE(ncharacter_expression)", description = "Returns Unicode code value of first character", returns = "int" },
  { name = "UPPER", signature = "UPPER(character_expression)", description = "Converts string to uppercase", returns = "varchar/nvarchar" },
  { name = "DATALENGTH", signature = "DATALENGTH(expression)", description = "Returns number of bytes used", returns = "int/bigint" },
}

-- =============================================================================
-- Date and Time Functions
-- =============================================================================
Functions.datetime = {
  { name = "CURRENT_TIMESTAMP", signature = "CURRENT_TIMESTAMP", description = "Returns current date and time (datetime)", returns = "datetime" },
  { name = "CURRENT_DATE", signature = "CURRENT_DATE", description = "Returns current date only", returns = "date" },
  { name = "DATEADD", signature = "DATEADD(datepart, number, date)", description = "Adds interval to date", returns = "datetime/date" },
  { name = "DATEDIFF", signature = "DATEDIFF(datepart, startdate, enddate)", description = "Returns difference between dates as int", returns = "int" },
  { name = "DATEDIFF_BIG", signature = "DATEDIFF_BIG(datepart, startdate, enddate)", description = "Returns difference between dates as bigint", returns = "bigint" },
  { name = "DATEFROMPARTS", signature = "DATEFROMPARTS(year, month, day)", description = "Returns date from parts", returns = "date" },
  { name = "DATENAME", signature = "DATENAME(datepart, date)", description = "Returns datepart as string", returns = "nvarchar" },
  { name = "DATEPART", signature = "DATEPART(datepart, date)", description = "Returns datepart as integer", returns = "int" },
  { name = "DATETIME2FROMPARTS", signature = "DATETIME2FROMPARTS(year, month, day, hour, minute, seconds, fractions, precision)", description = "Returns datetime2 from parts", returns = "datetime2" },
  { name = "DATETIMEFROMPARTS", signature = "DATETIMEFROMPARTS(year, month, day, hour, minute, seconds, milliseconds)", description = "Returns datetime from parts", returns = "datetime" },
  { name = "DATETIMEOFFSETFROMPARTS", signature = "DATETIMEOFFSETFROMPARTS(year, month, day, hour, minute, seconds, fractions, hour_offset, minute_offset, precision)", description = "Returns datetimeoffset from parts", returns = "datetimeoffset" },
  { name = "DATETRUNC", signature = "DATETRUNC(datepart, date)", description = "Truncates date to specified datepart (SQL Server 2022+)", returns = "datetime/date" },
  { name = "DATE_BUCKET", signature = "DATE_BUCKET(datepart, number, date [, origin])", description = "Returns bucket start date (SQL Server 2022+)", returns = "datetime/date" },
  { name = "DAY", signature = "DAY(date)", description = "Returns day of date", returns = "int" },
  { name = "EOMONTH", signature = "EOMONTH(start_date [, month_to_add])", description = "Returns last day of month", returns = "date" },
  { name = "GETDATE", signature = "GETDATE()", description = "Returns current date and time (datetime)", returns = "datetime" },
  { name = "GETUTCDATE", signature = "GETUTCDATE()", description = "Returns current UTC date and time", returns = "datetime" },
  { name = "ISDATE", signature = "ISDATE(expression)", description = "Returns 1 if expression is valid date", returns = "int" },
  { name = "MONTH", signature = "MONTH(date)", description = "Returns month of date", returns = "int" },
  { name = "SMALLDATETIMEFROMPARTS", signature = "SMALLDATETIMEFROMPARTS(year, month, day, hour, minute)", description = "Returns smalldatetime from parts", returns = "smalldatetime" },
  { name = "SWITCHOFFSET", signature = "SWITCHOFFSET(datetimeoffset, timezoneoffset)", description = "Changes timezone offset", returns = "datetimeoffset" },
  { name = "SYSDATETIME", signature = "SYSDATETIME()", description = "Returns current datetime2(7)", returns = "datetime2(7)" },
  { name = "SYSDATETIMEOFFSET", signature = "SYSDATETIMEOFFSET()", description = "Returns current datetimeoffset(7)", returns = "datetimeoffset(7)" },
  { name = "SYSUTCDATETIME", signature = "SYSUTCDATETIME()", description = "Returns current UTC datetime2(7)", returns = "datetime2(7)" },
  { name = "TIMEFROMPARTS", signature = "TIMEFROMPARTS(hour, minute, seconds, fractions, precision)", description = "Returns time from parts", returns = "time" },
  { name = "TODATETIMEOFFSET", signature = "TODATETIMEOFFSET(expression, time_zone)", description = "Converts to datetimeoffset", returns = "datetimeoffset" },
  { name = "YEAR", signature = "YEAR(date)", description = "Returns year of date", returns = "int" },
}

-- =============================================================================
-- Mathematical Functions
-- =============================================================================
Functions.mathematical = {
  { name = "ABS", signature = "ABS(numeric_expression)", description = "Returns absolute value", returns = "numeric" },
  { name = "ACOS", signature = "ACOS(float_expression)", description = "Returns arc cosine in radians", returns = "float" },
  { name = "ASIN", signature = "ASIN(float_expression)", description = "Returns arc sine in radians", returns = "float" },
  { name = "ATAN", signature = "ATAN(float_expression)", description = "Returns arc tangent in radians", returns = "float" },
  { name = "ATN2", signature = "ATN2(float_y, float_x)", description = "Returns arc tangent of y/x", returns = "float" },
  { name = "CEILING", signature = "CEILING(numeric_expression)", description = "Returns smallest integer >= value", returns = "numeric" },
  { name = "COS", signature = "COS(float_expression)", description = "Returns cosine", returns = "float" },
  { name = "COT", signature = "COT(float_expression)", description = "Returns cotangent", returns = "float" },
  { name = "DEGREES", signature = "DEGREES(numeric_expression)", description = "Converts radians to degrees", returns = "numeric" },
  { name = "EXP", signature = "EXP(float_expression)", description = "Returns e raised to power", returns = "float" },
  { name = "FLOOR", signature = "FLOOR(numeric_expression)", description = "Returns largest integer <= value", returns = "numeric" },
  { name = "LOG", signature = "LOG(float_expression [, base])", description = "Returns natural or base logarithm", returns = "float" },
  { name = "LOG10", signature = "LOG10(float_expression)", description = "Returns base-10 logarithm", returns = "float" },
  { name = "PI", signature = "PI()", description = "Returns value of pi", returns = "float" },
  { name = "POWER", signature = "POWER(float_expression, y)", description = "Returns value raised to power", returns = "float" },
  { name = "RADIANS", signature = "RADIANS(numeric_expression)", description = "Converts degrees to radians", returns = "numeric" },
  { name = "RAND", signature = "RAND([seed])", description = "Returns random float 0-1", returns = "float" },
  { name = "ROUND", signature = "ROUND(numeric_expression, length [, function])", description = "Rounds numeric value", returns = "numeric" },
  { name = "SIGN", signature = "SIGN(numeric_expression)", description = "Returns sign of value (-1, 0, 1)", returns = "numeric" },
  { name = "SIN", signature = "SIN(float_expression)", description = "Returns sine", returns = "float" },
  { name = "SQRT", signature = "SQRT(float_expression)", description = "Returns square root", returns = "float" },
  { name = "SQUARE", signature = "SQUARE(float_expression)", description = "Returns square of value", returns = "float" },
  { name = "TAN", signature = "TAN(float_expression)", description = "Returns tangent", returns = "float" },
}

-- =============================================================================
-- Conversion Functions
-- =============================================================================
Functions.conversion = {
  { name = "CAST", signature = "CAST(expression AS data_type)", description = "Converts expression to specified data type", returns = "data_type" },
  { name = "CONVERT", signature = "CONVERT(data_type, expression [, style])", description = "Converts with style option", returns = "data_type" },
  { name = "PARSE", signature = "PARSE(string_value AS data_type [USING culture])", description = "Parses string to date/number", returns = "data_type" },
  { name = "TRY_CAST", signature = "TRY_CAST(expression AS data_type)", description = "CAST that returns NULL on failure", returns = "data_type" },
  { name = "TRY_CONVERT", signature = "TRY_CONVERT(data_type, expression [, style])", description = "CONVERT that returns NULL on failure", returns = "data_type" },
  { name = "TRY_PARSE", signature = "TRY_PARSE(string_value AS data_type [USING culture])", description = "PARSE that returns NULL on failure", returns = "data_type" },
}

-- =============================================================================
-- Logical Functions
-- =============================================================================
Functions.logical = {
  { name = "CHOOSE", signature = "CHOOSE(index, val_1, val_2 [, val_n])", description = "Returns value at specified index", returns = "varies" },
  { name = "COALESCE", signature = "COALESCE(expression [, ...])", description = "Returns first non-NULL expression", returns = "varies" },
  { name = "GREATEST", signature = "GREATEST(expression [, ...])", description = "Returns greatest value (SQL Server 2022+)", returns = "varies" },
  { name = "IIF", signature = "IIF(boolean_expression, true_value, false_value)", description = "Returns value based on condition", returns = "varies" },
  { name = "LEAST", signature = "LEAST(expression [, ...])", description = "Returns smallest value (SQL Server 2022+)", returns = "varies" },
  { name = "NULLIF", signature = "NULLIF(expression, expression)", description = "Returns NULL if expressions equal", returns = "varies" },
}

-- =============================================================================
-- Ranking Functions (Window)
-- =============================================================================
Functions.ranking = {
  { name = "DENSE_RANK", signature = "DENSE_RANK() OVER ([PARTITION BY ...] ORDER BY ...)", description = "Returns rank without gaps for ties", returns = "bigint" },
  { name = "NTILE", signature = "NTILE(integer_expression) OVER ([PARTITION BY ...] ORDER BY ...)", description = "Distributes rows into specified number of groups", returns = "bigint" },
  { name = "RANK", signature = "RANK() OVER ([PARTITION BY ...] ORDER BY ...)", description = "Returns rank with gaps for ties", returns = "bigint" },
  { name = "ROW_NUMBER", signature = "ROW_NUMBER() OVER ([PARTITION BY ...] ORDER BY ...)", description = "Returns sequential row number", returns = "bigint" },
}

-- =============================================================================
-- Analytic Functions (Window)
-- =============================================================================
Functions.analytic = {
  { name = "CUME_DIST", signature = "CUME_DIST() OVER ([PARTITION BY ...] ORDER BY ...)", description = "Returns cumulative distribution", returns = "float" },
  { name = "FIRST_VALUE", signature = "FIRST_VALUE(expression) OVER (...)", description = "Returns first value in window frame", returns = "varies" },
  { name = "LAG", signature = "LAG(expression [, offset [, default]]) OVER (...)", description = "Returns value from previous row", returns = "varies" },
  { name = "LAST_VALUE", signature = "LAST_VALUE(expression) OVER (...)", description = "Returns last value in window frame", returns = "varies" },
  { name = "LEAD", signature = "LEAD(expression [, offset [, default]]) OVER (...)", description = "Returns value from next row", returns = "varies" },
  { name = "PERCENT_RANK", signature = "PERCENT_RANK() OVER ([PARTITION BY ...] ORDER BY ...)", description = "Returns relative rank as percentage", returns = "float" },
  { name = "PERCENTILE_CONT", signature = "PERCENTILE_CONT(percentile) WITHIN GROUP (ORDER BY ...) OVER (...)", description = "Returns continuous percentile value", returns = "float" },
  { name = "PERCENTILE_DISC", signature = "PERCENTILE_DISC(percentile) WITHIN GROUP (ORDER BY ...) OVER (...)", description = "Returns discrete percentile value", returns = "varies" },
}

-- =============================================================================
-- JSON Functions
-- =============================================================================
Functions.json = {
  { name = "ISJSON", signature = "ISJSON(expression)", description = "Tests if string is valid JSON", returns = "int" },
  { name = "JSON_ARRAY", signature = "JSON_ARRAY(value [, ...])", description = "Constructs JSON array (SQL Server 2022+)", returns = "nvarchar(max)" },
  { name = "JSON_MODIFY", signature = "JSON_MODIFY(expression, path, newValue)", description = "Updates value in JSON string", returns = "nvarchar(max)" },
  { name = "JSON_OBJECT", signature = "JSON_OBJECT(key:value [, ...])", description = "Constructs JSON object (SQL Server 2022+)", returns = "nvarchar(max)" },
  { name = "JSON_PATH_EXISTS", signature = "JSON_PATH_EXISTS(expression, path)", description = "Tests if path exists in JSON", returns = "int" },
  { name = "JSON_QUERY", signature = "JSON_QUERY(expression [, path])", description = "Extracts JSON object or array", returns = "nvarchar(max)" },
  { name = "JSON_VALUE", signature = "JSON_VALUE(expression, path)", description = "Extracts scalar value from JSON", returns = "nvarchar(4000)" },
  { name = "OPENJSON", signature = "OPENJSON(jsonExpression [, path]) [WITH (...)]", description = "Parses JSON into rows and columns", returns = "table" },
}

-- =============================================================================
-- System Functions
-- =============================================================================
Functions.system = {
  { name = "$PARTITION", signature = "$PARTITION.partition_function(expression)", description = "Returns partition number for value", returns = "int" },
  { name = "@@ERROR", signature = "@@ERROR", description = "Returns error number of last statement", returns = "int" },
  { name = "@@IDENTITY", signature = "@@IDENTITY", description = "Returns last inserted identity value (any scope)", returns = "numeric" },
  { name = "@@ROWCOUNT", signature = "@@ROWCOUNT", description = "Returns rows affected by last statement", returns = "int" },
  { name = "@@TRANCOUNT", signature = "@@TRANCOUNT", description = "Returns active transaction count", returns = "int" },
  { name = "BINARY_CHECKSUM", signature = "BINARY_CHECKSUM(* | expression [, ...])", description = "Returns binary checksum over row", returns = "int" },
  { name = "CHECKSUM", signature = "CHECKSUM(* | expression [, ...])", description = "Returns checksum over row", returns = "int" },
  { name = "COMPRESS", signature = "COMPRESS(expression)", description = "Compresses using GZIP", returns = "varbinary(max)" },
  { name = "CONNECTIONPROPERTY", signature = "CONNECTIONPROPERTY(property)", description = "Returns connection property value", returns = "sql_variant" },
  { name = "CONTEXT_INFO", signature = "CONTEXT_INFO()", description = "Returns context info binary", returns = "varbinary(128)" },
  { name = "CURRENT_REQUEST_ID", signature = "CURRENT_REQUEST_ID()", description = "Returns current request ID", returns = "smallint" },
  { name = "CURRENT_TRANSACTION_ID", signature = "CURRENT_TRANSACTION_ID()", description = "Returns current transaction ID", returns = "bigint" },
  { name = "DECOMPRESS", signature = "DECOMPRESS(expression)", description = "Decompresses GZIP data", returns = "varbinary(max)" },
  { name = "ERROR_LINE", signature = "ERROR_LINE()", description = "Returns line number where error occurred", returns = "int" },
  { name = "ERROR_MESSAGE", signature = "ERROR_MESSAGE()", description = "Returns error message text", returns = "nvarchar(4000)" },
  { name = "ERROR_NUMBER", signature = "ERROR_NUMBER()", description = "Returns error number", returns = "int" },
  { name = "ERROR_PROCEDURE", signature = "ERROR_PROCEDURE()", description = "Returns procedure name where error occurred", returns = "nvarchar(128)" },
  { name = "ERROR_SEVERITY", signature = "ERROR_SEVERITY()", description = "Returns error severity level", returns = "int" },
  { name = "ERROR_STATE", signature = "ERROR_STATE()", description = "Returns error state number", returns = "int" },
  { name = "FORMATMESSAGE", signature = "FORMATMESSAGE(msg_number | msg_string, param_value [, ...])", description = "Constructs message from format string", returns = "nvarchar" },
  { name = "GETANSINULL", signature = "GETANSINULL(['database'])", description = "Returns default nullability setting", returns = "int" },
  { name = "HOST_ID", signature = "HOST_ID()", description = "Returns workstation identification number", returns = "char(10)" },
  { name = "HOST_NAME", signature = "HOST_NAME()", description = "Returns workstation name", returns = "nvarchar(128)" },
  { name = "ISNULL", signature = "ISNULL(check_expression, replacement_value)", description = "Replaces NULL with specified value", returns = "varies" },
  { name = "ISNUMERIC", signature = "ISNUMERIC(expression)", description = "Returns 1 if expression is valid numeric", returns = "int" },
  { name = "MIN_ACTIVE_ROWVERSION", signature = "MIN_ACTIVE_ROWVERSION()", description = "Returns lowest active rowversion", returns = "binary(8)" },
  { name = "NEWID", signature = "NEWID()", description = "Creates unique uniqueidentifier (GUID)", returns = "uniqueidentifier" },
  { name = "NEWSEQUENTIALID", signature = "NEWSEQUENTIALID()", description = "Creates sequential GUID (default constraint only)", returns = "uniqueidentifier" },
  { name = "ROWCOUNT_BIG", signature = "ROWCOUNT_BIG()", description = "Returns rows affected as bigint", returns = "bigint" },
  { name = "SESSION_CONTEXT", signature = "SESSION_CONTEXT(N'key' [, @read_only])", description = "Returns session context value", returns = "sql_variant" },
  { name = "XACT_STATE", signature = "XACT_STATE()", description = "Returns transaction state (-1, 0, 1)", returns = "smallint" },
}

-- =============================================================================
-- Configuration Functions
-- =============================================================================
Functions.configuration = {
  { name = "@@DATEFIRST", signature = "@@DATEFIRST", description = "Returns first day of week setting (1-7)", returns = "tinyint" },
  { name = "@@DBTS", signature = "@@DBTS", description = "Returns current database timestamp", returns = "varbinary(8)" },
  { name = "@@LANGID", signature = "@@LANGID", description = "Returns current language ID", returns = "smallint" },
  { name = "@@LANGUAGE", signature = "@@LANGUAGE", description = "Returns current language name", returns = "nvarchar" },
  { name = "@@LOCK_TIMEOUT", signature = "@@LOCK_TIMEOUT", description = "Returns lock timeout setting in ms", returns = "int" },
  { name = "@@MAX_CONNECTIONS", signature = "@@MAX_CONNECTIONS", description = "Returns maximum connections allowed", returns = "int" },
  { name = "@@MAX_PRECISION", signature = "@@MAX_PRECISION", description = "Returns decimal/numeric precision", returns = "tinyint" },
  { name = "@@NESTLEVEL", signature = "@@NESTLEVEL", description = "Returns procedure nesting level", returns = "int" },
  { name = "@@OPTIONS", signature = "@@OPTIONS", description = "Returns current SET options bitmap", returns = "int" },
  { name = "@@REMSERVER", signature = "@@REMSERVER", description = "Returns remote server name", returns = "nvarchar(128)" },
  { name = "@@SERVERNAME", signature = "@@SERVERNAME", description = "Returns local server name", returns = "nvarchar(128)" },
  { name = "@@SERVICENAME", signature = "@@SERVICENAME", description = "Returns SQL Server service name", returns = "nvarchar(128)" },
  { name = "@@SPID", signature = "@@SPID", description = "Returns current session process ID", returns = "smallint" },
  { name = "@@TEXTSIZE", signature = "@@TEXTSIZE", description = "Returns TEXTSIZE setting", returns = "int" },
  { name = "@@VERSION", signature = "@@VERSION", description = "Returns SQL Server version info", returns = "nvarchar" },
}

-- =============================================================================
-- Security Functions
-- =============================================================================
Functions.security = {
  { name = "CERTENCODED", signature = "CERTENCODED(cert_id)", description = "Returns binary encoded certificate", returns = "varbinary(max)" },
  { name = "CERTPRIVATEKEY", signature = "CERTPRIVATEKEY(cert_id, password)", description = "Returns certificate private key", returns = "varbinary(max)" },
  { name = "CURRENT_USER", signature = "CURRENT_USER", description = "Returns current database user name", returns = "sysname" },
  { name = "DATABASE_PRINCIPAL_ID", signature = "DATABASE_PRINCIPAL_ID(['principal_name'])", description = "Returns database principal ID", returns = "int" },
  { name = "HAS_PERMS_BY_NAME", signature = "HAS_PERMS_BY_NAME(securable, securable_class, permission [, ...])", description = "Checks if user has permission", returns = "int" },
  { name = "IS_MEMBER", signature = "IS_MEMBER('group_or_role')", description = "Checks if user is member of role", returns = "int" },
  { name = "IS_ROLEMEMBER", signature = "IS_ROLEMEMBER('role' [, 'database_principal'])", description = "Checks database role membership", returns = "int" },
  { name = "IS_SRVROLEMEMBER", signature = "IS_SRVROLEMEMBER('role' [, 'login'])", description = "Checks server role membership", returns = "int" },
  { name = "LOGINPROPERTY", signature = "LOGINPROPERTY('login_name', 'property_name')", description = "Returns login property value", returns = "sql_variant" },
  { name = "ORIGINAL_LOGIN", signature = "ORIGINAL_LOGIN()", description = "Returns original login name (pre-impersonation)", returns = "sysname" },
  { name = "PERMISSIONS", signature = "PERMISSIONS([objectid [, 'column']])", description = "Returns permission bitmap", returns = "int" },
  { name = "PWDCOMPARE", signature = "PWDCOMPARE('clear_text', password_hash [, version])", description = "Compares password to hash", returns = "int" },
  { name = "PWDENCRYPT", signature = "PWDENCRYPT('password')", description = "Returns password hash (deprecated)", returns = "varbinary(128)" },
  { name = "SCHEMA_ID", signature = "SCHEMA_ID(['schema_name'])", description = "Returns schema ID", returns = "int" },
  { name = "SCHEMA_NAME", signature = "SCHEMA_NAME([schema_id])", description = "Returns schema name", returns = "sysname" },
  { name = "SESSION_USER", signature = "SESSION_USER", description = "Returns current session user name", returns = "sysname" },
  { name = "SUSER_ID", signature = "SUSER_ID(['login'])", description = "Returns login principal ID", returns = "int" },
  { name = "SUSER_NAME", signature = "SUSER_NAME([server_user_sid])", description = "Returns login name from SID", returns = "nvarchar(128)" },
  { name = "SUSER_SID", signature = "SUSER_SID(['login' [, Param2]])", description = "Returns login SID", returns = "varbinary(85)" },
  { name = "SUSER_SNAME", signature = "SUSER_SNAME([server_user_sid])", description = "Returns login name from SID", returns = "nvarchar(128)" },
  { name = "SYSTEM_USER", signature = "SYSTEM_USER", description = "Returns current system user name", returns = "nchar" },
  { name = "USER_ID", signature = "USER_ID(['user'])", description = "Returns database user ID", returns = "int" },
  { name = "USER_NAME", signature = "USER_NAME([user_id])", description = "Returns database user name", returns = "nvarchar(128)" },
}

-- =============================================================================
-- Metadata Functions
-- =============================================================================
Functions.metadata = {
  { name = "@@PROCID", signature = "@@PROCID", description = "Returns current stored procedure object ID", returns = "int" },
  { name = "APP_NAME", signature = "APP_NAME()", description = "Returns application name for session", returns = "nvarchar(128)" },
  { name = "APPLOCK_MODE", signature = "APPLOCK_MODE('database_principal', 'resource_name', 'lock_owner')", description = "Returns application lock mode", returns = "nvarchar(32)" },
  { name = "APPLOCK_TEST", signature = "APPLOCK_TEST('database_principal', 'resource_name', 'lock_mode', 'lock_owner')", description = "Tests if lock can be granted", returns = "smallint" },
  { name = "ASSEMBLYPROPERTY", signature = "ASSEMBLYPROPERTY('assembly_name', 'property_name')", description = "Returns assembly property", returns = "sql_variant" },
  { name = "COL_LENGTH", signature = "COL_LENGTH('table', 'column')", description = "Returns defined column length", returns = "int" },
  { name = "COL_NAME", signature = "COL_NAME(table_id, column_id)", description = "Returns column name", returns = "sysname" },
  { name = "COLUMNPROPERTY", signature = "COLUMNPROPERTY(id, column, property)", description = "Returns column property", returns = "int" },
  { name = "DATABASEPROPERTYEX", signature = "DATABASEPROPERTYEX(database, property)", description = "Returns database property", returns = "sql_variant" },
  { name = "DB_ID", signature = "DB_ID(['database_name'])", description = "Returns database ID", returns = "int" },
  { name = "DB_NAME", signature = "DB_NAME([database_id])", description = "Returns database name", returns = "nvarchar(128)" },
  { name = "FILE_ID", signature = "FILE_ID('file_name')", description = "Returns file ID", returns = "smallint" },
  { name = "FILE_IDEX", signature = "FILE_IDEX('file_name')", description = "Returns file ID (extended)", returns = "int" },
  { name = "FILE_NAME", signature = "FILE_NAME(file_id)", description = "Returns logical file name", returns = "nvarchar(128)" },
  { name = "FILEGROUP_ID", signature = "FILEGROUP_ID('filegroup_name')", description = "Returns filegroup ID", returns = "int" },
  { name = "FILEGROUP_NAME", signature = "FILEGROUP_NAME(filegroup_id)", description = "Returns filegroup name", returns = "nvarchar(128)" },
  { name = "FILEGROUPPROPERTY", signature = "FILEGROUPPROPERTY(filegroup_name, property)", description = "Returns filegroup property", returns = "int" },
  { name = "FILEPROPERTY", signature = "FILEPROPERTY(file_name, property)", description = "Returns file property", returns = "int" },
  { name = "FULLTEXTCATALOGPROPERTY", signature = "FULLTEXTCATALOGPROPERTY(catalog_name, property)", description = "Returns full-text catalog property", returns = "int" },
  { name = "FULLTEXTSERVICEPROPERTY", signature = "FULLTEXTSERVICEPROPERTY(property)", description = "Returns full-text service property", returns = "int" },
  { name = "INDEX_COL", signature = "INDEX_COL('table', index_id, key_id)", description = "Returns indexed column name", returns = "nvarchar(128)" },
  { name = "INDEXKEY_PROPERTY", signature = "INDEXKEY_PROPERTY(object_id, index_id, key_id, property)", description = "Returns index key property", returns = "int" },
  { name = "INDEXPROPERTY", signature = "INDEXPROPERTY(object_id, index_or_statistics_name, property)", description = "Returns index/statistics property", returns = "int" },
  { name = "OBJECT_DEFINITION", signature = "OBJECT_DEFINITION(object_id)", description = "Returns object definition (T-SQL)", returns = "nvarchar(max)" },
  { name = "OBJECT_ID", signature = "OBJECT_ID('object_name' [, 'object_type'])", description = "Returns object ID", returns = "int" },
  { name = "OBJECT_NAME", signature = "OBJECT_NAME(object_id [, database_id])", description = "Returns object name", returns = "sysname" },
  { name = "OBJECT_SCHEMA_NAME", signature = "OBJECT_SCHEMA_NAME(object_id [, database_id])", description = "Returns schema name for object", returns = "sysname" },
  { name = "OBJECTPROPERTY", signature = "OBJECTPROPERTY(id, property)", description = "Returns object property", returns = "int" },
  { name = "OBJECTPROPERTYEX", signature = "OBJECTPROPERTYEX(id, property)", description = "Returns object property (extended)", returns = "sql_variant" },
  { name = "ORIGINAL_DB_NAME", signature = "ORIGINAL_DB_NAME()", description = "Returns original database name", returns = "nvarchar(128)" },
  { name = "PARSENAME", signature = "PARSENAME('object_name', object_piece)", description = "Returns specified part of object name", returns = "nchar" },
  { name = "SCOPE_IDENTITY", signature = "SCOPE_IDENTITY()", description = "Returns last identity value in current scope", returns = "numeric" },
  { name = "SERVERPROPERTY", signature = "SERVERPROPERTY(property)", description = "Returns server property", returns = "sql_variant" },
  { name = "STATS_DATE", signature = "STATS_DATE(object_id, stats_id)", description = "Returns statistics update date", returns = "datetime" },
  { name = "TYPE_ID", signature = "TYPE_ID('type_name')", description = "Returns type ID", returns = "int" },
  { name = "TYPE_NAME", signature = "TYPE_NAME(type_id)", description = "Returns type name", returns = "sysname" },
  { name = "TYPEPROPERTY", signature = "TYPEPROPERTY(type, property)", description = "Returns type property", returns = "int" },
}

-- =============================================================================
-- Cursor Functions
-- =============================================================================
Functions.cursor = {
  { name = "@@CURSOR_ROWS", signature = "@@CURSOR_ROWS", description = "Returns number of qualifying rows in cursor", returns = "int" },
  { name = "@@FETCH_STATUS", signature = "@@FETCH_STATUS", description = "Returns status of last FETCH", returns = "int" },
  { name = "CURSOR_STATUS", signature = "CURSOR_STATUS('local' | 'global' | 'variable', cursor_name)", description = "Returns cursor status", returns = "smallint" },
}

-- =============================================================================
-- Rowset Functions
-- =============================================================================
Functions.rowset = {
  { name = "CONTAINSTABLE", signature = "CONTAINSTABLE(table, column, 'search_condition' [, ...])", description = "Full-text search returning ranks", returns = "table" },
  { name = "FREETEXTTABLE", signature = "FREETEXTTABLE(table, column, 'freetext_string' [, ...])", description = "Free-form text search returning ranks", returns = "table" },
  { name = "OPENQUERY", signature = "OPENQUERY(linked_server, 'query')", description = "Executes query on linked server", returns = "table" },
  { name = "OPENROWSET", signature = "OPENROWSET(provider_name, datasource, query | object)", description = "One-time ad hoc connection", returns = "table" },
  { name = "OPENXML", signature = "OPENXML(idoc, rowpattern [, flags]) [WITH (...)]", description = "Provides rowset view of XML", returns = "table" },
  { name = "GENERATE_SERIES", signature = "GENERATE_SERIES(start, stop [, step])", description = "Generates series of numbers (SQL Server 2022+)", returns = "table" },
}

-- =============================================================================
-- Helper Functions
-- =============================================================================

---Get all functions as a flat list
---@return FunctionDefinition[] functions All functions
function Functions.get_all()
  local result = {}
  for category, funcs in pairs(Functions) do
    if type(funcs) == "table" and category ~= "get_all" and category ~= "get_for_database"
        and category ~= "get_by_category" and category ~= "get_categories" then
      for _, func in ipairs(funcs) do
        func.category = category
        table.insert(result, func)
      end
    end
  end
  return result
end

---Get functions filtered by database type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return FunctionDefinition[] functions Functions for database
function Functions.get_for_database(db_type)
  -- Currently only SQL Server functions are defined
  -- For other databases, return empty or subset
  if db_type == "sqlserver" or db_type == "mssql" then
    return Functions.get_all()
  end
  -- For other databases, return common functions only
  -- (Would need to add postgres/mysql/sqlite specific functions)
  return {}
end

---Get functions by category
---@param category string Category name
---@return FunctionDefinition[] functions Functions in category
function Functions.get_by_category(category)
  local cat_funcs = Functions[category]
  if cat_funcs and type(cat_funcs) == "table" then
    local result = {}
    for _, func in ipairs(cat_funcs) do
      func.category = category
      table.insert(result, func)
    end
    return result
  end
  return {}
end

---Get list of available categories
---@return string[] categories List of category names
function Functions.get_categories()
  local categories = {}
  for category, value in pairs(Functions) do
    if type(value) == "table" and category ~= "get_all" and category ~= "get_for_database"
        and category ~= "get_by_category" and category ~= "get_categories" then
      table.insert(categories, category)
    end
  end
  table.sort(categories)
  return categories
end

return Functions
