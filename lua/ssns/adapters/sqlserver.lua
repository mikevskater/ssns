local BaseAdapter = require('ssns.adapters.base')

---@class SqlServerAdapter : BaseAdapter
local SqlServerAdapter = setmetatable({}, { __index = BaseAdapter })
SqlServerAdapter.__index = SqlServerAdapter

---Create a new SQL Server adapter instance
---@param connection_string string
---@return SqlServerAdapter
function SqlServerAdapter.new(connection_string)
  local self = setmetatable(BaseAdapter.new("sqlserver", connection_string), SqlServerAdapter)

  -- SQL Server feature flags
  self.features = {
    schemas = true,      -- SQL Server supports schemas
    synonyms = true,     -- SQL Server supports synonyms
    procedures = true,   -- Stored procedures
    functions = true,    -- User-defined functions
    sequences = true,    -- Sequences (SQL Server 2012+)
    triggers = true,     -- Triggers
    views = true,        -- Views
    indexes = true,      -- Indexes
    constraints = true,  -- Constraints (PK, FK, CHECK, etc.)
  }

  return self
end

---Execute a query against SQL Server using vim-dadbod or Node.js backend
---@param connection any The database connection object or connection string
---@param query string The SQL query to execute
---@param opts table? Options { use_delimiter: boolean, include_headers: boolean }
---@return table results Array of result rows
function SqlServerAdapter:execute(connection, query, opts)
  local Debug = require('ssns.debug')
  Debug.log("SqlServerAdapter:execute called")

  opts = opts or { use_delimiter = true }
  local ConnectionModule = require('ssns.connection')
  local Config = require('ssns.config')

  Debug.log("Determining connection string")
  -- Handle both connection object and connection string
  local conn_str
  if type(connection) == "string" then
    conn_str = connection
  elseif type(connection) == "table" and connection.connection_string then
    conn_str = connection.connection_string
  else
    -- Fallback to adapter's connection string
    conn_str = self.connection_string
  end

  Debug.log("Checking which backend to use")
  -- Check if Node.js backend should be used
  local results, err
  if Config.use_nodejs() then
    Debug.log("Using Node.js backend")
    -- Use Node.js backend (Phase 7)
    results, err = ConnectionModule.execute_nodejs(conn_str, query)
    Debug.log("Node.js backend returned")
  else
    Debug.log("Using vim-dadbod backend")
    -- Use vim-dadbod
    results, err = ConnectionModule.execute_sync(conn_str, query, opts)
    Debug.log("vim-dadbod backend returned")
  end

  if err then
    -- Log error but return empty results for now
    -- UI layer can check for errors separately
    vim.notify(string.format("SSNS SQL Error: %s", err), vim.log.levels.WARN)
    return {}
  end

  return results
end

---Execute a query against SQL Server asynchronously
---@param connection any The database connection object or connection string
---@param query string The SQL query to execute
---@param callback function Callback function(results, error)
function SqlServerAdapter:execute_async(connection, query, callback)
  local ConnectionModule = require('ssns.connection')

  -- Handle both connection object and connection string
  local conn_str
  if type(connection) == "string" then
    conn_str = connection
  elseif type(connection) == "table" and connection.connection_string then
    conn_str = connection.connection_string
  else
    conn_str = self.connection_string
  end

  -- Execute async
  ConnectionModule.execute_async(conn_str, query, callback)
end

---Parse SQL Server connection string
---@return table connection_info
function SqlServerAdapter:parse_connection_string()
  -- Format: sqlserver://[user:password@]host[\instance]/database
  local info = {}

  local pattern = "^sqlserver://(.+)$"
  local rest = self.connection_string:match(pattern)

  if not rest then
    return info
  end

  -- Extract user:password if present
  local auth, host_db = rest:match("^([^@]+)@(.+)$")
  if auth then
    info.user, info.password = auth:match("^([^:]+):(.+)$")
    rest = host_db
  else
    rest = rest
  end

  -- Extract host/instance and database
  local host_part, database = rest:match("^([^/]+)/(.+)$")
  if host_part then
    info.database = database

    -- Check for instance name
    local host, instance = host_part:match("^([^\\]+)\\(.+)$")
    if host then
      info.host = host
      info.instance = instance
    else
      info.host = host_part
    end
  end

  return info
end

---Test SQL Server connection
---@param connection any
---@return boolean success
---@return string? error_message
function SqlServerAdapter:test_connection(connection)
  local ConnectionModule = require('ssns.connection')

  -- Handle both connection object and connection string
  local conn_str
  if type(connection) == "string" then
    conn_str = connection
  elseif type(connection) == "table" and connection.connection_string then
    conn_str = connection.connection_string
  else
    conn_str = self.connection_string
  end

  return ConnectionModule.test(conn_str)
end

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list all databases on the SQL Server
---@return string query
function SqlServerAdapter:get_databases_query()
  return [[
SELECT name
FROM sys.databases
WHERE database_id > 4  -- Exclude system databases (master, tempdb, model, msdb)
  AND state_desc = 'ONLINE'
  AND HAS_DBACCESS(name) = 1  -- User has access
ORDER BY name;
]]
end

---Get query to list all schemas in a database
---@param database_name string
---@return string query
function SqlServerAdapter:get_schemas_query(database_name)
  return string.format([[
USE [%s];
SELECT s.name
FROM sys.schemas s
WHERE s.schema_id < 16384  -- Exclude system schemas
  AND s.name NOT IN ('guest', 'INFORMATION_SCHEMA', 'sys')
ORDER BY s.name;
]], database_name)
end

---Get query to list all tables in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_tables_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  t.name AS table_name,
  t.type_desc AS table_type
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0  -- Exclude system tables
%sORDER BY s.name, t.name;
]], database_name, where_clause)
end

---Get query to list all views in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_views_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  v.name AS view_name
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE v.is_ms_shipped = 0  -- Exclude system views
%sORDER BY s.name, v.name;
]], database_name, where_clause)
end

---Get query to list all stored procedures in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_procedures_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  p.name AS procedure_name
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE p.is_ms_shipped = 0  -- Exclude system procedures
%sORDER BY s.name, p.name;
]], database_name, where_clause)
end

---Get query to list all functions in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_functions_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  o.name AS function_name,
  o.type_desc AS function_type
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('FN', 'IF', 'TF')  -- Scalar, Inline Table-Valued, Table-Valued
  AND o.is_ms_shipped = 0  -- Exclude system functions
%sORDER BY s.name, o.name;
]], database_name, where_clause)
end

---Get query to list all synonyms in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_synonyms_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  syn.name AS synonym_name,
  syn.base_object_name
FROM sys.synonyms syn
INNER JOIN sys.schemas s ON syn.schema_id = s.schema_id
WHERE syn.is_ms_shipped = 0
%sORDER BY s.name, syn.name;
]], database_name, where_clause)
end

---Get query to list all sequences in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function SqlServerAdapter:get_sequences_query(database_name, schema_name)
  local where_clause = ""
  if schema_name then
    where_clause = string.format("  AND s.name = '%s'\n", schema_name)
  end

  return string.format([[
USE [%s];
SELECT
  s.name AS schema_name,
  seq.name AS sequence_name,
  seq.start_value,
  seq.increment,
  seq.current_value
FROM sys.sequences seq
INNER JOIN sys.schemas s ON seq.schema_id = s.schema_id
WHERE seq.is_ms_shipped = 0
%sORDER BY s.name, seq.name;
]], database_name, where_clause)
end

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_columns_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SELECT
  c.name AS column_name,
  t.name AS data_type,
  c.max_length,
  c.precision,
  c.scale,
  c.is_nullable,
  c.is_identity,
  OBJECT_DEFINITION(c.default_object_id) AS default_value,
  c.column_id AS ordinal_position
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o ON c.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.name = '%s'
  AND o.type IN ('U', 'V')  -- U = User Table, V = View
  %s
ORDER BY c.column_id;
]], database_name, table_name, schema_filter)
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_indexes_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SELECT
  i.name AS index_name,
  i.type_desc AS index_type,
  i.is_unique,
  i.is_primary_key,
  i.is_unique_constraint,
  STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS column_names
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE t.name = '%s'
  %s
  AND i.type > 0  -- Exclude heap (type 0)
GROUP BY i.name, i.type_desc, i.is_unique, i.is_primary_key, i.is_unique_constraint
ORDER BY i.is_primary_key DESC, i.name;
]], database_name, table_name, schema_filter)
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_constraints_query(database_name, schema_name, table_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SELECT
  con.name AS constraint_name,
  con.type_desc AS constraint_type,
  STRING_AGG(c.name, ', ') AS column_names,
  fk_schema.name AS referenced_schema,
  fk_table.name AS referenced_table,
  STRING_AGG(fk_col.name, ', ') AS referenced_columns
FROM sys.objects con
INNER JOIN sys.tables t ON con.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.foreign_key_columns fkc ON con.object_id = fkc.constraint_object_id
LEFT JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
LEFT JOIN sys.tables fk_table ON fkc.referenced_object_id = fk_table.object_id
LEFT JOIN sys.schemas fk_schema ON fk_table.schema_id = fk_schema.schema_id
LEFT JOIN sys.columns fk_col ON fkc.referenced_object_id = fk_col.object_id AND fkc.referenced_column_id = fk_col.column_id
WHERE con.type IN ('PK', 'F', 'UQ', 'C', 'D')  -- Primary Key, Foreign Key, Unique, Check, Default
  AND t.name = '%s'
  %s
GROUP BY con.name, con.type_desc, fk_schema.name, fk_table.name
ORDER BY con.type_desc, con.name;
]], database_name, table_name, schema_filter)
end

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string?
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function SqlServerAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SELECT
  CASE
    WHEN p.parameter_id = 0 THEN 'RETURNS'
    ELSE p.name
  END AS parameter_name,
  t.name AS data_type,
  p.max_length,
  p.precision,
  p.scale,
  p.is_output,
  p.has_default_value,
  p.parameter_id AS ordinal_position,
  CASE
    WHEN p.parameter_id = 0 THEN 1  -- Return value sorts last
    ELSE 0
  END AS is_return_value
FROM sys.parameters p
INNER JOIN sys.types t ON p.user_type_id = t.user_type_id
INNER JOIN sys.objects o ON p.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.name = '%s'
  %s
ORDER BY is_return_value, p.parameter_id;
]], database_name, routine_name, schema_filter)
end

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string?
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function SqlServerAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  -- This query is based on the FuncsViewsAndProcsALL.sql file
  -- It retrieves the definition using OBJECT_DEFINITION
  -- Returns only the definition column for the specified object
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""
  local name_filter = object_name and string.format("AND o.name = '%s'", object_name) or ""

  return string.format([[
USE [%s];
SELECT
    OBJECT_DEFINITION(o.object_id) AS definition
FROM sys.objects o WITH (NOWAIT)
JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
WHERE o.[type] NOT IN ('S', 'IT', 'PK', 'U')
    AND o.is_ms_shipped = 0
    %s
    %s;
]], database_name, schema_filter, name_filter)
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_table_definition_query(database_name, schema_name, table_name)
  -- This query is based on the tableDefinitionALL.sql file
  -- It constructs a complete CREATE TABLE script with columns, constraints, foreign keys, and indexes
  local table_filter = string.format("%s.%s", schema_name or "dbo", table_name)

  return string.format([[
USE [%s];

DECLARE @table_name VARCHAR(800) = '%s';
DECLARE @object_name SYSNAME, @object_id INT;

SELECT
    @object_name = '[' + s.name + '].[' + o.name + ']',
    @object_id = o.[object_id]
FROM sys.objects o WITH (NOWAIT)
JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
WHERE s.name + '.' + o.name = @table_name
    AND o.[type] = 'U'
    AND o.is_ms_shipped = 0;

DECLARE @SQL NVARCHAR(MAX) = N'';

WITH index_column AS (
    SELECT ic.[object_id], ic.index_id, ic.is_descending_key, ic.is_included_column, c.name
    FROM sys.index_columns ic WITH (NOWAIT)
    JOIN sys.columns c WITH (NOWAIT) ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
    WHERE ic.[object_id] = @object_id
),
fk_columns AS (
    SELECT k.constraint_object_id, cname = c.name, rcname = rc.name
    FROM sys.foreign_key_columns k WITH (NOWAIT)
    JOIN sys.columns rc WITH (NOWAIT) ON rc.[object_id] = k.referenced_object_id AND rc.column_id = k.referenced_column_id
    JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = k.parent_object_id AND c.column_id = k.parent_column_id
    WHERE k.parent_object_id = @object_id
)
SELECT @SQL = N'CREATE TABLE ' + @object_name + CHAR(10) + N'(' + CHAR(10)
    + STUFF((
        SELECT CHAR(9) + ', [' + c.name + '] '
            + CASE WHEN c.is_computed = 1 THEN 'AS ' + cc.[definition]
                ELSE UPPER(tp.name)
                    + CASE
                        WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text') THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('nvarchar', 'nchar', 'ntext') THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
                        WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
                        WHEN tp.name IN ('decimal', 'numeric') THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                        ELSE ''
                    END
                    + CASE WHEN c.collation_name IS NOT NULL THEN ' COLLATE ' + c.collation_name ELSE '' END
                    + CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END
                    + CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT' + dc.[definition] ELSE '' END
                    + CASE WHEN ic.is_identity = 1 THEN ' IDENTITY(' + CAST(ISNULL(ic.seed_value, '0') AS CHAR(1)) + ',' + CAST(ISNULL(ic.increment_value, '1') AS CHAR(1)) + ')' ELSE '' END
            END + CHAR(10)
        FROM sys.columns c WITH (NOWAIT)
        JOIN sys.types tp WITH (NOWAIT) ON c.user_type_id = tp.user_type_id
        LEFT JOIN sys.computed_columns cc WITH (NOWAIT) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
        LEFT JOIN sys.default_constraints dc WITH (NOWAIT) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
        LEFT JOIN sys.identity_columns ic WITH (NOWAIT) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
        WHERE c.[object_id] = @object_id
        ORDER BY c.column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, CHAR(9) + ' ')
    + ISNULL((
        SELECT CHAR(9) + ', CONSTRAINT [' + k.name + '] PRIMARY KEY (' +
            STUFF((
                SELECT ', [' + c.name + '] ' + CASE WHEN ic.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END
                FROM sys.index_columns ic WITH (NOWAIT)
                JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
                WHERE ic.is_included_column = 0 AND ic.[object_id] = k.parent_object_id AND ic.index_id = k.unique_index_id
                FOR XML PATH(N''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')' + CHAR(10)
        FROM sys.key_constraints k WITH (NOWAIT)
        WHERE k.parent_object_id = @object_id AND k.[type] = 'PK'
    ), '')
    + N')' + CHAR(10)
    + ISNULL((
        SELECT CHAR(10) + 'ALTER TABLE ' + @object_name + ' WITH' + CASE WHEN fk.is_not_trusted = 1 THEN ' NOCHECK' ELSE ' CHECK' END
            + ' ADD CONSTRAINT [' + fk.name + '] FOREIGN KEY('
            + STUFF((SELECT ', [' + k.cname + ']' FROM fk_columns k WHERE k.constraint_object_id = fk.[object_id] FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
            + ') REFERENCES [' + SCHEMA_NAME(ro.[schema_id]) + '].[' + ro.name + '] ('
            + STUFF((SELECT ', [' + k.rcname + ']' FROM fk_columns k WHERE k.constraint_object_id = fk.[object_id] FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
            + ')' + CASE WHEN fk.delete_referential_action = 1 THEN ' ON DELETE CASCADE' WHEN fk.delete_referential_action = 2 THEN ' ON DELETE SET NULL' WHEN fk.delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT' ELSE '' END
            + CASE WHEN fk.update_referential_action = 1 THEN ' ON UPDATE CASCADE' WHEN fk.update_referential_action = 2 THEN ' ON UPDATE SET NULL' WHEN fk.update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT' ELSE '' END
            + CHAR(10) + 'ALTER TABLE ' + @object_name + ' CHECK CONSTRAINT [' + fk.name + ']' + CHAR(10)
        FROM sys.foreign_keys fk WITH (NOWAIT)
        JOIN sys.objects ro WITH (NOWAIT) ON ro.[object_id] = fk.referenced_object_id
        WHERE fk.parent_object_id = @object_id
        FOR XML PATH(N''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), '')
    + ISNULL((
        SELECT CHAR(10) + 'CREATE' + CASE WHEN i.is_unique = 1 THEN ' UNIQUE' ELSE '' END + ' NONCLUSTERED INDEX [' + i.name + '] ON ' + @object_name
            + ' (' + STUFF((SELECT ', [' + c.name + ']' + CASE WHEN c.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END FROM index_column c WHERE c.is_included_column = 0 AND c.index_id = i.index_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')'
            + ISNULL(CHAR(10) + 'INCLUDE (' + STUFF((SELECT ', [' + c.name + ']' FROM index_column c WHERE c.is_included_column = 1 AND c.index_id = i.index_id FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')', '')
            + CHAR(10)
        FROM sys.indexes i WITH (NOWAIT)
        WHERE i.[object_id] = @object_id AND i.is_primary_key = 0 AND i.[type] = 2
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), '');

SELECT @SQL AS definition;
]], database_name, table_filter)
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results
---@param results table
---@return table databases
function SqlServerAdapter:parse_databases(results)
  local databases = {}
  for _, row in ipairs(results) do
    table.insert(databases, { name = row.name or row[1] })
  end
  return databases
end

---Parse schema list results
---@param results table
---@return table schemas
function SqlServerAdapter:parse_schemas(results)
  local schemas = {}
  for _, row in ipairs(results) do
    table.insert(schemas, { name = row.name or row[1] })
  end
  return schemas
end

---Parse table list results
---@param results table
---@return table tables
function SqlServerAdapter:parse_tables(results)
  local tables = {}
  for _, row in ipairs(results) do
    table.insert(tables, {
      schema = row.schema_name or row[1],
      name = row.table_name or row[2],
      type = row.table_type or row[3],
    })
  end
  return tables
end

---Parse view list results
---@param results table
---@return table views
function SqlServerAdapter:parse_views(results)
  local views = {}
  for _, row in ipairs(results) do
    table.insert(views, {
      schema = row.schema_name or row[1],
      name = row.view_name or row[2],
    })
  end
  return views
end

---Parse procedure list results
---@param results table
---@return table procedures
function SqlServerAdapter:parse_procedures(results)
  local procedures = {}
  for _, row in ipairs(results) do
    table.insert(procedures, {
      schema = row.schema_name or row[1],
      name = row.procedure_name or row[2],
    })
  end
  return procedures
end

---Parse function list results
---@param results table
---@return table functions
function SqlServerAdapter:parse_functions(results)
  local funcs = {}
  for _, row in ipairs(results) do
    table.insert(funcs, {
      schema = row.schema_name or row[1],
      name = row.function_name or row[2],
      type = row.function_type or row[3],
    })
  end
  return funcs
end

---Parse column list results
---@param results table
---@return table columns
function SqlServerAdapter:parse_columns(results)
  local columns = {}
  for _, row in ipairs(results) do
    table.insert(columns, {
      name = row.column_name or row[1],
      data_type = row.data_type or row[2],
      max_length = row.max_length,
      precision = row.precision,
      scale = row.scale,
      nullable = row.is_nullable == 1 or row.is_nullable == true,
      is_identity = row.is_identity == 1 or row.is_identity == true,
      default = row.default_value,
      ordinal_position = row.ordinal_position,
    })
  end
  return columns
end

---Parse index list results
---@param results table
---@return table indexes
function SqlServerAdapter:parse_indexes(results)
  local indexes = {}
  for _, row in ipairs(results) do
    table.insert(indexes, {
      name = row.index_name or row[1],
      type = row.index_type or row[2],
      is_unique = row.is_unique == 1 or row.is_unique == true,
      is_primary = row.is_primary_key == 1 or row.is_primary_key == true,
      columns = vim.split(row.column_names or "", ", ", { plain = true }),
    })
  end
  return indexes
end

---Parse constraint list results
---@param results table
---@return table constraints
function SqlServerAdapter:parse_constraints(results)
  local constraints = {}
  for _, row in ipairs(results) do
    table.insert(constraints, {
      name = row.constraint_name or row[1],
      type = row.constraint_type or row[2],
      columns = vim.split(row.column_names or "", ", ", { plain = true }),
      referenced_table = row.referenced_table,
      referenced_schema = row.referenced_schema,
      referenced_columns = row.referenced_columns and vim.split(row.referenced_columns, ", ", { plain = true }) or nil,
    })
  end
  return constraints
end

---Parse parameter list results
---@param results table
---@return table parameters
function SqlServerAdapter:parse_parameters(results)
  local parameters = {}
  for _, row in ipairs(results) do
    table.insert(parameters, {
      name = row.parameter_name or row[1],
      data_type = row.data_type or row[2],
      max_length = row.max_length,
      precision = row.precision,
      scale = row.scale,
      mode = (row.is_output == 1 or row.is_output == true) and "OUT" or "IN",
      has_default = row.has_default_value == 1 or row.has_default_value == true,
      ordinal_position = row.ordinal_position,
    })
  end
  return parameters
end

-- ============================================================================
-- Object Creation Helpers
-- ============================================================================

---Create a table object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SqlServerAdapter:create_table(parent, row)
  local TableClass = require('ssns.classes.table')
  return TableClass.new({
    name = row.name,
    schema_name = row.schema,
    table_type = row.type,
    parent = parent,
  })
end

---Create a view object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SqlServerAdapter:create_view(parent, row)
  local ViewClass = require('ssns.classes.view')
  return ViewClass.new({
    name = row.name,
    schema_name = row.schema,
    parent = parent,
  })
end

---Create a procedure object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SqlServerAdapter:create_procedure(parent, row)
  local ProcedureClass = require('ssns.classes.procedure')
  return ProcedureClass.new({
    name = row.name,
    schema_name = row.schema,
    parent = parent,
  })
end

---Create a function object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SqlServerAdapter:create_function(parent, row)
  local FunctionClass = require('ssns.classes.function')
  return FunctionClass.new({
    name = row.name,
    schema_name = row.schema,
    function_type = row.type,
    parent = parent,
  })
end

---Create a column object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SqlServerAdapter:create_column(parent, row)
  local ColumnClass = require('ssns.classes.column')
  return ColumnClass.new({
    name = row.name,
    data_type = row.data_type,
    nullable = row.nullable,
    is_identity = row.is_identity,
    default = row.default,
    max_length = row.max_length,
    precision = row.precision,
    scale = row.scale,
    parent = parent,
  })
end

---Get query to fetch object dependencies
---@param database_name string
---@param schema_name string
---@param object_name string
---@return string query
function SqlServerAdapter:get_dependencies_query(database_name, schema_name, object_name)
  return string.format([[
USE [%s];
-- Get objects that THIS object depends on (referenced objects)
SELECT
  'DEPENDS ON' AS dependency_type,
  OBJECT_SCHEMA_NAME(d.referenced_id) AS schema_name,
  OBJECT_NAME(d.referenced_id) AS object_name,
  o.type_desc AS object_type
FROM sys.sql_expression_dependencies d
INNER JOIN sys.objects o ON d.referenced_id = o.object_id
WHERE d.referencing_id = OBJECT_ID('[%s].[%s]')

UNION ALL

-- Get objects that depend ON this object (referencing objects)
SELECT
  'DEPENDED ON BY' AS dependency_type,
  OBJECT_SCHEMA_NAME(d.referencing_id) AS schema_name,
  OBJECT_NAME(d.referencing_id) AS object_name,
  o.type_desc AS object_type
FROM sys.sql_expression_dependencies d
INNER JOIN sys.objects o ON d.referencing_id = o.object_id
WHERE d.referenced_id = OBJECT_ID('[%s].[%s]')

ORDER BY dependency_type, schema_name, object_name;
]], database_name, schema_name, object_name, schema_name, object_name)
end

---Parse dependencies query results
---@param results table
---@return table dependencies Array of dependency objects
function SqlServerAdapter:parse_dependencies(results)
  local dependencies = {}

  for _, row in ipairs(results) do
    table.insert(dependencies, {
      dependency_type = row[1] or row.dependency_type,
      schema_name = row[2] or row.schema_name,
      object_name = row[3] or row.object_name,
      object_type = row[4] or row.object_type,
    })
  end

  return dependencies
end

-- ============================================================================
-- Utility Methods
-- ============================================================================

---Get the identifier quote character for SQL Server
---@return string
function SqlServerAdapter:get_quote_char()
  return "["  -- SQL Server uses [brackets]
end

---Get a string representation for debugging
---@return string
function SqlServerAdapter:to_string()
  return string.format("SqlServerAdapter{connection=%s}", self.connection_string)
end

return SqlServerAdapter
