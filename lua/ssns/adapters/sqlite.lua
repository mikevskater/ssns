local BaseAdapter = require('ssns.adapters.base')

---@class SQLiteAdapter : BaseAdapter
local SQLiteAdapter = setmetatable({}, { __index = BaseAdapter })
SQLiteAdapter.__index = SQLiteAdapter

---Create a new SQLite adapter instance
---@param connection_config ConnectionData
---@return SQLiteAdapter
function SQLiteAdapter.new(connection_config)
  local self = setmetatable(BaseAdapter.new("sqlite", connection_config), SQLiteAdapter)

  -- SQLite feature flags
  self.features = {
    schemas = false,     -- SQLite doesn't have schemas (all objects in main database)
    synonyms = false,    -- SQLite doesn't support synonyms
    procedures = false,  -- SQLite doesn't support stored procedures
    functions = false,   -- SQLite has built-in functions but not user-defined functions (in standard SQLite)
    sequences = false,   -- SQLite doesn't have sequences (uses AUTOINCREMENT)
    triggers = true,     -- Triggers
    views = true,        -- Views
    indexes = true,      -- Indexes
    constraints = true,  -- Constraints (PK, FK, CHECK, etc.)
  }

  return self
end

---Execute a query against SQLite using Node.js backend
---@param connection ConnectionData? The connection config (optional, uses adapter's config if nil)
---@param query string The SQL query to execute
---@param opts table? Options (reserved for future use)
---@return table result Node.js result object { success, resultSets, metadata, error }
function SQLiteAdapter:execute(connection, query, opts)
  opts = opts or {}
  local ConnectionModule = require('ssns.connection')

  -- Use passed connection config if provided, otherwise use adapter's config
  local conn_config = connection or self.connection_config
  return ConnectionModule.execute(conn_config, query, opts)
end

---Test SQLite connection
---@param connection any
---@return boolean success
---@return string? error_message
function SQLiteAdapter:test_connection(connection)
  local ConnectionModule = require('ssns.connection')
  return ConnectionModule.test(self.connection_config)
end

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list databases (SQLite only has one database - the file itself)
---@return string query
function SQLiteAdapter:get_databases_query()
  -- SQLite doesn't have multiple databases, just return the main database
  -- This query returns a single row with the database name
  return "SELECT 'main' AS name;"
end

---Get query to list all tables in the SQLite database
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@return string query
function SQLiteAdapter:get_tables_query(database_name, schema_name)
  return [[
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;
]]
end

---Get query to list all views in the SQLite database
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@return string query
function SQLiteAdapter:get_views_query(database_name, schema_name)
  return [[
SELECT name
FROM sqlite_master
WHERE type = 'view'
ORDER BY name;
]]
end

---Get query to list all columns in a table or view
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@param table_name string
---@return string query
function SQLiteAdapter:get_columns_query(database_name, schema_name, table_name)
  return string.format([[
PRAGMA table_info(%s);
]], table_name)
end

---Get query to list all indexes on a table
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@param table_name string
---@return string query
function SQLiteAdapter:get_indexes_query(database_name, schema_name, table_name)
  return string.format([[
PRAGMA index_list(%s);
]], table_name)
end

---Get query to list all foreign keys on a table
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@param table_name string
---@return string query
function SQLiteAdapter:get_constraints_query(database_name, schema_name, table_name)
  -- SQLite doesn't have a direct constraint query, use foreign_key_list
  return string.format([[
PRAGMA foreign_key_list(%s);
]], table_name)
end

---Get query to retrieve the definition of a view
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function SQLiteAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  return string.format([[
SELECT sql AS definition
FROM sqlite_master
WHERE type = 'view'
  AND name = '%s';
]], object_name)
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@param table_name string
---@return string query
function SQLiteAdapter:get_table_definition_query(database_name, schema_name, table_name)
  return string.format([[
SELECT sql AS definition
FROM sqlite_master
WHERE type = 'table'
  AND name = '%s';
]], table_name)
end

---Parse table definition result and return normalized format
---@param result table Node.js result object
---@return string? definition The CREATE TABLE statement
function SQLiteAdapter:parse_table_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      return rows[1].definition
    end
  end
  return nil
end

---Parse object definition result (for views)
---@param result table Node.js result object
---@return string? definition The object definition
function SQLiteAdapter:parse_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      return rows[1].definition
    end
  end
  return nil
end

-- ============================================================================
-- Bulk Loading Methods (for SSNSSearch)
-- ============================================================================

---Get query to retrieve table/view definitions for parsing column names
---SQLite doesn't have a bulk column query, so we get CREATE statements and parse them
---@param database_name string? Not used in SQLite
---@return string query
function SQLiteAdapter:get_all_columns_bulk_query(database_name)
  -- Return table/view definitions - column names will be parsed from the SQL
  return [[
SELECT
  name AS table_name,
  CASE type WHEN 'table' THEN 'table' ELSE 'view' END AS object_type,
  sql AS definition
FROM sqlite_master
WHERE type IN ('table', 'view')
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;
]]
end

---Parse column names from CREATE TABLE/VIEW SQL statements
---@param sql string The CREATE TABLE/VIEW statement
---@return string[] columns Array of column names
local function parse_columns_from_sql(sql)
  local columns = {}
  if not sql then return columns end

  -- Try to extract columns from CREATE TABLE
  local cols_section = sql:match("CREATE%s+TABLE%s+[%[%]%w_]+%s*%((.-)%)")
  if not cols_section then
    -- Try CREATE VIEW - extract column names from SELECT
    cols_section = sql:match("AS%s+SELECT%s+(.-)%s+FROM")
  end

  if cols_section then
    -- Simple column extraction - look for column definitions or SELECT items
    for col in cols_section:gmatch("[%[%]]?([%w_]+)[%[%]]?%s+[%w%(%)]+") do
      if col and col ~= "" and not col:match("^%d") then
        -- Skip SQL keywords
        local upper = col:upper()
        if upper ~= "PRIMARY" and upper ~= "FOREIGN" and upper ~= "KEY"
            and upper ~= "UNIQUE" and upper ~= "CHECK" and upper ~= "CONSTRAINT"
            and upper ~= "NOT" and upper ~= "NULL" and upper ~= "DEFAULT"
            and upper ~= "REFERENCES" and upper ~= "INTEGER" and upper ~= "TEXT"
            and upper ~= "REAL" and upper ~= "BLOB" and upper ~= "NUMERIC" then
          table.insert(columns, col)
        end
      end
    end
  end

  return columns
end

---Parse bulk columns result into metadata map
---@param result table Node.js result object
---@return table<string, string> metadata Map of "schema.object_type.name" -> "col1 col2 col3 ..."
function SQLiteAdapter:parse_all_columns_bulk(result)
  local metadata = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.table_name and row.definition then
        -- SQLite doesn't have schemas, use 'main' as placeholder
        local key = string.format("main.%s.%s", row.object_type or "table", row.table_name)
        local columns = parse_columns_from_sql(row.definition)
        if #columns > 0 then
          metadata[key] = table.concat(columns, " ")
        end
      end
    end
  end

  return metadata
end

---SQLite doesn't support stored procedures, so this returns an empty query
---@param database_name string? Not used
---@return string query
function SQLiteAdapter:get_all_parameters_bulk_query(database_name)
  -- SQLite doesn't have stored procedures
  return "SELECT 1 WHERE 0;"  -- Empty result
end

---SQLite doesn't support stored procedures, so this returns empty metadata
---@param result table Node.js result object
---@return table<string, string> metadata Always empty for SQLite
function SQLiteAdapter:parse_all_parameters_bulk(result)
  return {}  -- SQLite doesn't have stored procedures
end

---Get query to retrieve ALL definitions for views in a database
---Note: SQLite doesn't have procedures/functions
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@return string query
function SQLiteAdapter:get_all_definitions_bulk_query(database_name, schema_name)
  -- SQLite only has views (no procedures/functions)
  return [[
SELECT
  name AS object_name,
  'view' AS object_type,
  sql AS definition
FROM sqlite_master
WHERE type = 'view'
ORDER BY name;
]]
end

---Parse bulk definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.object_type.name" -> definition
function SQLiteAdapter:parse_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.object_name and row.definition then
        -- SQLite doesn't have schemas, use 'main' as placeholder
        local key = string.format("main.%s.%s", row.object_type, row.object_name)
        definitions[key] = row.definition
      end
    end
  end

  return definitions
end

---Get query to retrieve CREATE TABLE scripts for ALL tables in a database
---@param database_name string? Not used in SQLite
---@param schema_name string? Not used in SQLite
---@return string query
function SQLiteAdapter:get_all_table_definitions_bulk_query(database_name, schema_name)
  return [[
SELECT
  name AS table_name,
  'table' AS object_type,
  sql AS definition
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;
]]
end

---Parse bulk table definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.table.name" -> definition
function SQLiteAdapter:parse_table_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.table_name and row.definition then
        -- SQLite doesn't have schemas, use 'main' as placeholder
        local key = string.format("main.table.%s", row.table_name)
        definitions[key] = row.definition
      end
    end
  end

  return definitions
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results (SQLite always returns 'main')
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table databases Array of { name } objects
function SQLiteAdapter:parse_databases(result)
  local databases = {}

  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.name then
        table.insert(databases, { name = row.name })
      end
    end
  end

  return databases
end

---Parse table list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table tables
function SQLiteAdapter:parse_tables(result)
  local tables = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(tables, {
        name = row.name,
        type = "BASE TABLE",
      })
    end
  end
  return tables
end

---Parse view list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table views
function SQLiteAdapter:parse_views(result)
  local views = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(views, {
        name = row.name,
      })
    end
  end
  return views
end

---Parse column list results (from PRAGMA table_info)
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table columns
function SQLiteAdapter:parse_columns(result)
  local columns = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(columns, {
        name = row.name,
        data_type = row.type,
        nullable = row.notnull == 0,
        is_identity = row.pk == 1,  -- Primary key in SQLite
        default = row.dflt_value,
        ordinal_position = row.cid,
      })
    end
  end
  return columns
end

---Parse index list results (from PRAGMA index_list)
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table indexes
function SQLiteAdapter:parse_indexes(result)
  local indexes = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(indexes, {
        name = row.name,
        is_unique = row.unique == 1,
        is_primary = row.origin == "pk",
        columns = {},  -- Would need PRAGMA index_info(index_name) to get columns
      })
    end
  end
  return indexes
end

---Parse constraint list results (from PRAGMA foreign_key_list)
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table constraints
function SQLiteAdapter:parse_constraints(result)
  local constraints = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(constraints, {
        name = string.format("FK_%s_%s", row.table, row.from),
        type = "FOREIGN KEY",
        columns = { row.from },
        referenced_table = row.table,
        referenced_columns = { row.to },
      })
    end
  end
  return constraints
end

-- ============================================================================
-- Object Creation Helpers
-- ============================================================================

---Create a table object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SQLiteAdapter:create_table(parent, row)
  local TableClass = require('ssns.classes.table')
  return TableClass.new({
    name = row.name,
    table_type = row.type,
    parent = parent,
  })
end

---Create a view object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SQLiteAdapter:create_view(parent, row)
  local ViewClass = require('ssns.classes.view')
  return ViewClass.new({
    name = row.name,
    parent = parent,
  })
end

---Create a column object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function SQLiteAdapter:create_column(parent, row)
  local ColumnClass = require('ssns.classes.column')
  return ColumnClass.new({
    name = row.name,
    data_type = row.data_type,
    nullable = row.nullable,
    is_identity = row.is_identity,
    default = row.default,
    parent = parent,
  })
end

-- ============================================================================
-- Utility Methods
-- ============================================================================

---Get the identifier quote character for SQLite
---@return string
function SQLiteAdapter:get_quote_char()
  return '"'  -- SQLite uses double quotes (also supports backticks and brackets)
end

---Get a string representation for debugging
---@return string
function SQLiteAdapter:to_string()
  local db_path = ""
  if self.connection_config and self.connection_config.server then
    db_path = self.connection_config.server.database or self.connection_config.server.host or ""
  end
  return string.format("SQLiteAdapter{database=%s}", db_path)
end

return SQLiteAdapter
