---SQL Server metadata query generation
---Complex queries for columns, indexes, constraints, parameters, and definitions
---@class SqlServerMetadata
local M = {}

-- ============================================================================
-- Column Queries
-- ============================================================================

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function M.get_columns_query(database_name, schema_name, table_name)
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
function M.get_columns_bulk_query(database_name, schema_name)
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
function M.get_all_columns_bulk_query(database_name)
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

---Get query to list columns of a table-valued function (TVF)
---@param database_name string
---@param schema_name string?
---@param function_name string
---@return string query
function M.get_tvf_columns_query(database_name, schema_name, function_name)
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

-- ============================================================================
-- Parameter Queries
-- ============================================================================

---Get query to retrieve ALL parameters for ALL procedures/functions in a database
---Used for bulk metadata loading in object search
---@param database_name string
---@return string query
function M.get_all_parameters_bulk_query(database_name)
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

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string?
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function M.get_parameters_query(database_name, schema_name, routine_name, routine_type)
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

-- ============================================================================
-- Index and Constraint Queries
-- ============================================================================

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function M.get_indexes_query(database_name, schema_name, table_name)
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
function M.get_constraints_query(database_name, schema_name, table_name)
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

-- ============================================================================
-- Definition Queries
-- ============================================================================

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string?
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function M.get_definition_query(database_name, schema_name, object_name, object_type)
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
function M.get_table_definition_query(database_name, schema_name, table_name)
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

---Get query to retrieve ALL definitions for views, procedures, functions in a database
---Uses sys.sql_modules for efficient bulk loading (does NOT include tables - those need CREATE TABLE scripts)
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function M.get_all_definitions_bulk_query(database_name, schema_name)
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

---Get query to retrieve CREATE TABLE scripts for ALL tables in a database
---This is a set-based version of get_table_definition_query that processes all tables at once
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function M.get_all_table_definitions_bulk_query(database_name, schema_name)
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

-- ============================================================================
-- Dependency Queries
-- ============================================================================

---Get query to fetch object dependencies
---@param database_name string
---@param schema_name string
---@param object_name string
---@return string query
function M.get_dependencies_query(database_name, schema_name, object_name)
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

return M
