local BaseAdapter = require('ssns.adapters.base')

---@class SqlServerAdapter : BaseAdapter
local SqlServerAdapter = setmetatable({}, { __index = BaseAdapter })
SqlServerAdapter.__index = SqlServerAdapter

---Create a new SQL Server adapter instance
---@param connection_config ConnectionData
---@return SqlServerAdapter
function SqlServerAdapter.new(connection_config)
  local self = setmetatable(BaseAdapter.new("sqlserver", connection_config), SqlServerAdapter)

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

---Execute a query against SQL Server using Node.js backend
---@param connection ConnectionData? The connection config (optional, uses adapter's config if nil)
---@param query string The SQL query to execute
---@param opts table? Options (reserved for future use)
---@return table result Node.js result object { success, resultSets, metadata, error }
function SqlServerAdapter:execute(connection, query, opts)
  opts = opts or {}
  local ConnectionModule = require('ssns.connection')

  -- Use passed connection config if provided, otherwise use adapter's config
  local conn_config = connection or self.connection_config
  return ConnectionModule.execute(conn_config, query, opts)
end

---Test SQL Server connection
---@param connection any
---@return boolean success
---@return string? error_message
function SqlServerAdapter:test_connection(connection)
  local ConnectionModule = require('ssns.connection')
  return ConnectionModule.test(self.connection_config)
end

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list all databases on the SQL Server
---@return string query
function SqlServerAdapter:get_databases_query()
  return [[
SET NOCOUNT ON;

SELECT name
FROM sys.databases
WHERE HAS_DBACCESS(name) = 1  -- User has access;
]]
end

---Get query to list all schemas in a database
---@param database_name string
---@return string query
function SqlServerAdapter:get_schemas_query(database_name)
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT s.name
FROM sys.schemas s;
]], database_name)
end

---Get query to list all tables in a database
---@param database_name string
---@param schema_name string? Optional schema name to filter by
---@return string query
function SqlServerAdapter:get_tables_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("WHERE s.name = '%s'", schema_name) or ""
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  t.name AS table_name,
  t.type_desc AS table_type
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
%s;
]], database_name, schema_filter)
end

---Get query to list all views in a database
---@param database_name string
---@param schema_name string? Optional schema name to filter by
---@return string query
function SqlServerAdapter:get_views_query(database_name, schema_name)
  -- Always use sys.all_views to include system catalog views (sys.objects, sys.columns, etc.)
  -- This allows completion to work with sys.█ queries
  local schema_filter = schema_name and string.format("WHERE s.name = '%s'", schema_name) or ""
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  v.name AS view_name
FROM sys.all_views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
%s;
]], database_name, schema_filter)
end

---Get query to list all stored procedures in a database
---@param database_name string
---@param schema_name string? Optional schema name to filter by
---@return string query
function SqlServerAdapter:get_procedures_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("WHERE s.name = '%s'", schema_name) or ""
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  p.name AS procedure_name
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
%s;
]], database_name, schema_filter)
end

---Get query to list all functions in a database
---@param database_name string
---@param schema_name string? Optional schema name to filter by
---@return string query
function SqlServerAdapter:get_functions_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  o.name AS function_name,
  o.type_desc AS function_type
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('FN', 'IF', 'TF')  -- Scalar, Inline Table-Valued, Table-Valued
%s;
]], database_name, schema_filter)
end

---Get query to list all synonyms in a database
---@param database_name string
---@param schema_name string? Optional schema name to filter by
---@return string query
function SqlServerAdapter:get_synonyms_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("WHERE s.name = '%s'", schema_name) or ""
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  syn.name AS synonym_name,
  syn.base_object_name
FROM sys.synonyms syn
INNER JOIN sys.schemas s ON syn.schema_id = s.schema_id
%s;
]], database_name, schema_filter)
end

---Get query to list all sequences in a database
---@param database_name string
---@return string query
function SqlServerAdapter:get_sequences_query(database_name)
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  seq.name AS sequence_name,
  seq.start_value,
  seq.increment,
  seq.current_value
FROM sys.sequences seq
INNER JOIN sys.schemas s ON seq.schema_id = s.schema_id;
]], database_name)
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
SET NOCOUNT ON;

SELECT
  c.name AS column_name,
  t.name AS data_type,
  c.max_length,
  c.precision,
  c.scale,
  c.is_nullable,
  c.is_identity,
  c.is_computed,
  OBJECT_DEFINITION(c.default_object_id) AS default_value,
  c.column_id AS ordinal_position
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o ON c.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.name = '%s'
  AND o.type IN ('U', 'V')  -- U = User Table, V = View
  %s;
]], database_name, table_name, schema_filter)
end

---Get query to bulk load all columns for all tables and views in a schema
---This is more efficient than loading columns one table at a time
---@param database_name string
---@param schema_name string
---@return string query
function SqlServerAdapter:get_columns_bulk_query(database_name, schema_name)
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  o.name AS table_name,
  s.name AS schema_name,
  c.name AS column_name,
  t.name AS data_type,
  c.max_length,
  c.precision,
  c.scale,
  c.is_nullable,
  c.is_identity,
  c.is_computed,
  OBJECT_DEFINITION(c.default_object_id) AS default_value,
  c.column_id AS ordinal_position
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o ON c.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('U', 'V')  -- U = User Table, V = View
  AND s.name = '%s'
ORDER BY o.name, c.column_id;
]], database_name, schema_name)
end

---Get query to retrieve ALL columns for ALL tables/views/TVFs in a database (no schema filter)
---Combines table/view columns with table-valued function return columns in one query
---Used for bulk metadata loading in object search
---@param database_name string
---@return string query
function SqlServerAdapter:get_all_columns_bulk_query(database_name)
  return string.format([[
USE [%s];
SET NOCOUNT ON;

-- Table and View columns
SELECT
  s.name AS schema_name,
  o.name AS table_name,
  CASE o.type WHEN 'U' THEN 'table' WHEN 'V' THEN 'view' END AS object_type,
  c.name AS column_name,
  t.name AS data_type,
  c.column_id AS sort_order
FROM sys.columns c WITH (NOWAIT)
INNER JOIN sys.types t WITH (NOWAIT) ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o WITH (NOWAIT) ON c.object_id = o.object_id
INNER JOIN sys.schemas s WITH (NOWAIT) ON o.schema_id = s.schema_id
WHERE o.type IN ('U', 'V')  -- U = User Table, V = View
  AND o.is_ms_shipped = 0

UNION ALL

-- Table-valued function return columns
SELECT
  s.name AS schema_name,
  o.name AS table_name,
  'function' AS object_type,
  c.name AS column_name,
  t.name AS data_type,
  c.column_id AS sort_order
FROM sys.columns c WITH (NOWAIT)
INNER JOIN sys.types t WITH (NOWAIT) ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o WITH (NOWAIT) ON c.object_id = o.object_id
INNER JOIN sys.schemas s WITH (NOWAIT) ON o.schema_id = s.schema_id
WHERE o.type IN ('IF', 'TF')  -- IF = Inline TVF, TF = Multi-Statement TVF
  AND o.is_ms_shipped = 0

--ORDER BY schema_name, table_name, sort_order;
]], database_name)
end

---Get query to retrieve ALL parameters for ALL procedures/functions in a database
---Used for bulk metadata loading in object search
---@param database_name string
---@return string query
function SqlServerAdapter:get_all_parameters_bulk_query(database_name)
  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  s.name AS schema_name,
  o.name AS routine_name,
  CASE o.type
    WHEN 'P' THEN 'procedure'
    WHEN 'FN' THEN 'function'
    WHEN 'IF' THEN 'function'
    WHEN 'TF' THEN 'function'
  END AS object_type,
  CASE
    WHEN p.parameter_id = 0 THEN 'RETURNS'
    ELSE p.name
  END AS parameter_name,
  t.name AS data_type
FROM sys.parameters p WITH (NOWAIT)
INNER JOIN sys.types t WITH (NOWAIT) ON p.user_type_id = t.user_type_id
INNER JOIN sys.objects o WITH (NOWAIT) ON p.object_id = o.object_id
INNER JOIN sys.schemas s WITH (NOWAIT) ON o.schema_id = s.schema_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF')  -- P = Procedure, FN/IF/TF = Functions
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name, p.parameter_id;
]], database_name)
end

---Parse bulk columns result into metadata map
---@param result table Node.js result object
---@return table<string, string> metadata Map of "schema.object_type.name" -> "col1 type1 col2 type2 ..."
function SqlServerAdapter:parse_all_columns_bulk(result)
  local metadata = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    -- Group columns by table
    local columns_by_table = {}
    for _, row in ipairs(rows) do
      if row.schema_name and row.table_name and row.column_name then
        local key = string.format("%s.%s.%s", row.schema_name, row.object_type, row.table_name)
        if not columns_by_table[key] then
          columns_by_table[key] = {}
        end
        table.insert(columns_by_table[key], row.column_name)
        if row.data_type then
          table.insert(columns_by_table[key], row.data_type)
        end
      end
    end
    -- Concatenate column info into searchable text
    for key, parts in pairs(columns_by_table) do
      metadata[key] = table.concat(parts, " ")
    end
  end

  return metadata
end

---Parse bulk parameters result into metadata map
---@param result table Node.js result object
---@return table<string, string> metadata Map of "schema.object_type.name" -> "param1 type1 param2 type2 ..."
function SqlServerAdapter:parse_all_parameters_bulk(result)
  local metadata = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    -- Group parameters by routine
    local params_by_routine = {}
    for _, row in ipairs(rows) do
      if row.schema_name and row.routine_name and row.parameter_name then
        local key = string.format("%s.%s.%s", row.schema_name, row.object_type, row.routine_name)
        if not params_by_routine[key] then
          params_by_routine[key] = {}
        end
        table.insert(params_by_routine[key], row.parameter_name)
        if row.data_type then
          table.insert(params_by_routine[key], row.data_type)
        end
      end
    end
    -- Concatenate parameter info into searchable text
    for key, parts in pairs(params_by_routine) do
      metadata[key] = table.concat(parts, " ")
    end
  end

  return metadata
end

---Get query to list columns of a table-valued function (TVF)
---@param database_name string
---@param schema_name string?
---@param function_name string
---@return string query
function SqlServerAdapter:get_tvf_columns_query(database_name, schema_name, function_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
  c.name AS column_name,
  t.name AS data_type,
  c.max_length,
  c.precision,
  c.scale,
  c.is_nullable,
  c.column_id AS ordinal_position
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
INNER JOIN sys.objects o ON c.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.name = '%s'
  AND o.type IN ('IF', 'TF')  -- IF = Inline Table-Valued, TF = Multi-Statement Table-Valued
  %s;
]], database_name, function_name, schema_filter)
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
SET NOCOUNT ON;

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
GROUP BY i.name, i.type_desc, i.is_unique, i.is_primary_key, i.is_unique_constraint;
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
SET NOCOUNT ON;

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
GROUP BY con.name, con.type_desc, fk_schema.name, fk_table.name;
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
SET NOCOUNT ON;

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
  %s;
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
SET NOCOUNT ON;

SELECT
    OBJECT_DEFINITION(o.object_id) AS definition
FROM sys.objects o WITH (NOWAIT)
JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
WHERE o.[type] NOT IN ('S', 'IT', 'PK', 'U')
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
SET NOCOUNT ON;

DECLARE @table_name VARCHAR(800) = '%s';
DECLARE @object_name SYSNAME, @object_id INT;

SELECT
    @object_name = '[' + s.name + '].[' + o.name + ']',
    @object_id = o.[object_id]
FROM sys.objects o WITH (NOWAIT)
JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
WHERE s.name + '.' + o.name = @table_name
    AND o.[type] = 'U';

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

---Parse table definition result and return normalized format
---@param result table Node.js result object
---@return string? definition The CREATE TABLE statement
function SqlServerAdapter:parse_table_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      return rows[1].definition
    end
  end
  return nil
end

---Parse object definition result (for views, procedures, functions)
---@param result table Node.js result object
---@return string? definition The object definition
function SqlServerAdapter:parse_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      local definition = rows[1].definition
      -- Remove Windows-style carriage returns (\r) to normalize line endings
      -- OBJECT_DEFINITION() returns \r\n, but we want just \n for consistency
      if definition then
        definition = definition:gsub('\r', '')
      end
      return definition
    end
  end
  return nil
end

---Get query to retrieve ALL definitions for views, procedures, functions in a database
---Uses sys.sql_modules for efficient bulk loading (does NOT include tables - those need CREATE TABLE scripts)
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function SqlServerAdapter:get_all_definitions_bulk_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SET NOCOUNT ON;

SELECT
    s.name AS schema_name,
    o.name AS object_name,
    CASE o.[type]
        WHEN 'V' THEN 'view'
        WHEN 'P' THEN 'procedure'
        WHEN 'FN' THEN 'function'
        WHEN 'IF' THEN 'function'
        WHEN 'TF' THEN 'function'
        WHEN 'TR' THEN 'trigger'
        ELSE o.[type]
    END AS object_type,
    m.[definition] AS definition
FROM sys.sql_modules m WITH (NOWAIT)
JOIN sys.objects o WITH (NOWAIT) ON m.[object_id] = o.[object_id]
JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
WHERE o.[type] IN ('V', 'P', 'FN', 'IF', 'TF')
    AND o.is_ms_shipped = 0
    %s
ORDER BY s.name, o.name;
]], database_name, schema_filter)
end

---Parse bulk definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.object_type.name" -> definition
function SqlServerAdapter:parse_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.schema_name and row.object_name and row.definition then
        local key = string.format("%s.%s.%s", row.schema_name, row.object_type, row.object_name)
        local definition = row.definition
        -- Normalize line endings
        if definition then
          definition = definition:gsub('\r', '')
        end
        definitions[key] = definition
      end
    end
  end

  return definitions
end

---Get query to retrieve CREATE TABLE scripts for ALL tables in a database
---This is a set-based version of get_table_definition_query that processes all tables at once
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function SqlServerAdapter:get_all_table_definitions_bulk_query(database_name, schema_name)
  local schema_filter = schema_name and string.format("AND s.name = '%s'", schema_name) or ""

  return string.format([[
USE [%s];
SET NOCOUNT ON;

-- Build CREATE TABLE scripts for all user tables
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    'table' AS object_type,
    N'CREATE TABLE [' + s.name + N'].[' + t.name + N']' + CHAR(10) + N'(' + CHAR(10)
    + STUFF((
        SELECT CHAR(9) + N', [' + c.name + N'] '
            + CASE WHEN c.is_computed = 1 THEN N'AS ' + ISNULL(cc.[definition], N'')
                ELSE UPPER(tp.name)
                    + CASE
                        WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text') THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length AS NVARCHAR(5)) END + N')'
                        WHEN tp.name IN ('nvarchar', 'nchar', 'ntext') THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length / 2 AS NVARCHAR(5)) END + N')'
                        WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') THEN N'(' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        WHEN tp.name IN ('decimal', 'numeric') THEN N'(' + CAST(c.[precision] AS NVARCHAR(5)) + N',' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        ELSE N''
                    END
                    + CASE WHEN c.collation_name IS NOT NULL AND c.collation_name <> DATABASEPROPERTYEX(DB_NAME(), 'Collation') THEN N' COLLATE ' + c.collation_name ELSE N'' END
                    + CASE WHEN c.is_nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                    + CASE WHEN dc.[definition] IS NOT NULL THEN N' DEFAULT' + dc.[definition] ELSE N'' END
                    + CASE WHEN ic.is_identity = 1 THEN N' IDENTITY(' + CAST(ISNULL(ic.seed_value, 0) AS NVARCHAR(10)) + N',' + CAST(ISNULL(ic.increment_value, 1) AS NVARCHAR(10)) + N')' ELSE N'' END
            END + CHAR(10)
        FROM sys.columns c WITH (NOWAIT)
        JOIN sys.types tp WITH (NOWAIT) ON c.user_type_id = tp.user_type_id
        LEFT JOIN sys.computed_columns cc WITH (NOWAIT) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
        LEFT JOIN sys.default_constraints dc WITH (NOWAIT) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
        LEFT JOIN sys.identity_columns ic WITH (NOWAIT) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
        WHERE c.[object_id] = t.[object_id]
        ORDER BY c.column_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, CHAR(9) + N' ')
    + ISNULL((
        SELECT CHAR(9) + N', CONSTRAINT [' + k.name + N'] PRIMARY KEY (' +
            STUFF((
                SELECT N', [' + col.name + N'] ' + CASE WHEN ixc.is_descending_key = 1 THEN N'DESC' ELSE N'ASC' END
                FROM sys.index_columns ixc WITH (NOWAIT)
                JOIN sys.columns col WITH (NOWAIT) ON col.[object_id] = ixc.[object_id] AND col.column_id = ixc.column_id
                WHERE ixc.is_included_column = 0 AND ixc.[object_id] = k.parent_object_id AND ixc.index_id = k.unique_index_id
                FOR XML PATH(N''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') + N')' + CHAR(10)
        FROM sys.key_constraints k WITH (NOWAIT)
        WHERE k.parent_object_id = t.[object_id] AND k.[type] = 'PK'
    ), N'')
    + N')' AS definition
FROM sys.tables t WITH (NOWAIT)
JOIN sys.schemas s WITH (NOWAIT) ON t.[schema_id] = s.[schema_id]
WHERE t.is_ms_shipped = 0
    %s
ORDER BY s.name, t.name;
]], database_name, schema_filter)
end

---Parse bulk table definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.table.name" -> definition
function SqlServerAdapter:parse_table_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.schema_name and row.table_name and row.definition then
        local key = string.format("%s.table.%s", row.schema_name, row.table_name)
        local definition = row.definition
        -- Normalize line endings
        if definition then
          definition = definition:gsub('\r', '')
        end
        definitions[key] = definition
      end
    end
  end

  return definitions
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table databases Array of { name } objects
function SqlServerAdapter:parse_databases(result)
  local databases = {}

  -- Extract rows from first result set
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Extract 'name' column value
      if row.name then
        table.insert(databases, { name = row.name })
      end
    end
  end

  return databases
end

---Parse schema list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table schemas Array of { name } objects
function SqlServerAdapter:parse_schemas(result)
  local schemas = {}

  -- Extract rows from first result set
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Extract 'name' column value
      if row.name then
        table.insert(schemas, { name = row.name })
      end
    end
  end

  return schemas
end

---Parse table list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table tables
function SqlServerAdapter:parse_tables(result)
  local tables = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(tables, {
        schema = row.schema_name,
        name = row.table_name,
        type = row.table_type,
      })
    end
  end
  return tables
end

---Parse view list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table views
function SqlServerAdapter:parse_views(result)
  local views = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(views, {
        schema = row.schema_name,
        name = row.view_name,
      })
    end
  end
  return views
end

---Parse procedure list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table procedures
function SqlServerAdapter:parse_procedures(result)
  local procedures = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(procedures, {
        schema = row.schema_name,
        name = row.procedure_name,
      })
    end
  end
  return procedures
end

---Parse function list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table functions
function SqlServerAdapter:parse_functions(result)
  local funcs = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(funcs, {
        schema = row.schema_name,
        name = row.function_name,
        type = row.function_type,
      })
    end
  end
  return funcs
end

---Parse synonym list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table synonyms
function SqlServerAdapter:parse_synonyms(result)
  local synonyms = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(synonyms, {
        schema = row.schema_name,
        name = row.synonym_name,
        base_object_name = row.base_object_name,
        base_object_type = nil,  -- SQL Server sys.synonyms doesn't provide base type
      })
    end
  end
  return synonyms
end

---Parse column list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table columns
function SqlServerAdapter:parse_columns(result)
  local columns = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(columns, {
        name = row.column_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.precision,
        scale = row.scale,
        nullable = row.is_nullable == 1 or row.is_nullable == true,
        is_identity = row.is_identity == 1 or row.is_identity == true,
        is_computed = row.is_computed == 1 or row.is_computed == true,
        default = row.default_value,
        ordinal_position = row.ordinal_position,
      })
    end
  end
  return columns
end

---Parse index list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table indexes
function SqlServerAdapter:parse_indexes(result)
  local indexes = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(indexes, {
        name = row.index_name,
        type = row.index_type,
        is_unique = self:to_boolean(row.is_unique),
        is_primary = self:to_boolean(row.is_primary_key),
        columns = self:parse_column_list(row.column_names),
      })
    end
  end
  return indexes
end

---Parse constraint list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table constraints
function SqlServerAdapter:parse_constraints(result)
  local constraints = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      local ref_columns = self:parse_column_list(row.referenced_columns)

      table.insert(constraints, {
        name = row.constraint_name,
        type = row.constraint_type,
        columns = self:parse_column_list(row.column_names),
        referenced_table = self:safe_get(row.referenced_table),
        referenced_schema = self:safe_get(row.referenced_schema),
        referenced_columns = #ref_columns > 0 and ref_columns or nil,
      })
    end
  end
  return constraints
end

---Parse parameter list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table parameters
function SqlServerAdapter:parse_parameters(result)
  local parameters = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- Skip return value (parameter_name = 'RETURNS')
      if row.parameter_name ~= 'RETURNS' and row.is_return_value ~= 1 then
        -- Format data type with length/precision
        local data_type = row.data_type
        if row.max_length and row.max_length > 0 and row.max_length ~= -1 then
          if data_type:match("char") or data_type:match("binary") then
            local length = row.max_length
            if data_type:match("n") then -- nvarchar, nchar use double bytes
              length = length / 2
            end
            if length == -1 then
              data_type = data_type .. "(MAX)"
            else
              data_type = data_type .. "(" .. length .. ")"
            end
          end
        elseif row.precision and row.precision > 0 then
          if row.scale and row.scale > 0 then
            data_type = data_type .. "(" .. row.precision .. "," .. row.scale .. ")"
          else
            data_type = data_type .. "(" .. row.precision .. ")"
          end
        end

        table.insert(parameters, {
          name = row.parameter_name,
          data_type = data_type,
          direction = (row.is_output == 1 or row.is_output == true) and "OUT" or "IN",
          default_value = nil,  -- SQL Server doesn't expose default value in sys.parameters
          is_nullable = true,  -- SQL Server parameters are generally nullable unless NOT NULL specified
          has_default = row.has_default_value == 1 or row.has_default_value == true,
          ordinal_position = row.ordinal_position,
        })
      end
    end
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
SET NOCOUNT ON;

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
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table dependencies Array of dependency objects
function SqlServerAdapter:parse_dependencies(result)
  local dependencies = {}

  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(dependencies, {
        dependency_type = row.dependency_type,
        schema_name = row.schema_name,
        object_name = row.object_name,
        object_type = row.object_type,
      })
    end
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
  local server_info = ""
  if self.connection_config and self.connection_config.server then
    server_info = self.connection_config.server.host or ""
    if self.connection_config.server.instance then
      server_info = server_info .. "\\" .. self.connection_config.server.instance
    end
  end
  return string.format("SqlServerAdapter{server=%s}", server_info)
end

return SqlServerAdapter
