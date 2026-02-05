local BaseAdapter = require('nvim-ssns.adapters.base')

---@class MySQLAdapter : BaseAdapter
local MySQLAdapter = setmetatable({}, { __index = BaseAdapter })
MySQLAdapter.__index = MySQLAdapter

---Create a new MySQL adapter instance
---@param connection_config ConnectionData
---@return MySQLAdapter
function MySQLAdapter.new(connection_config)
  local self = setmetatable(BaseAdapter.new("mysql", connection_config), MySQLAdapter)

  -- MySQL feature flags
  self.features = {
    schemas = false,     -- MySQL uses databases, not schemas (schema = database)
    synonyms = false,    -- MySQL doesn't support synonyms
    procedures = true,   -- Stored procedures
    functions = true,    -- User-defined functions
    sequences = false,   -- MySQL doesn't have sequences (uses AUTO_INCREMENT)
    triggers = true,     -- Triggers
    views = true,        -- Views
    indexes = true,      -- Indexes
    constraints = true,  -- Constraints (PK, FK, CHECK, etc.)
  }

  return self
end

-- execute() and test_connection() inherited from BaseAdapter

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list all databases on the MySQL server
---@return string query
function MySQLAdapter:get_databases_query()
  return [[
SELECT schema_name AS name
FROM information_schema.schemata
WHERE schema_name NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY schema_name;
]]
end

---Get query to list all tables in a database
---@param database_name string
---@param schema_name string? Not used in MySQL (schema = database)
---@return string query
function MySQLAdapter:get_tables_query(database_name, schema_name)
  return string.format([[
SELECT
  table_name AS name,
  table_type AS type
FROM information_schema.tables
WHERE table_schema = '%s'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
]], database_name)
end

---Get query to list all views in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_views_query(database_name, schema_name)
  return string.format([[
SELECT
  table_name AS name
FROM information_schema.views
WHERE table_schema = '%s'
ORDER BY table_name;
]], database_name)
end

---Get query to list all stored procedures in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_procedures_query(database_name, schema_name)
  return string.format([[
SELECT
  routine_name AS name
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_type = 'PROCEDURE'
ORDER BY routine_name;
]], database_name)
end

---Get query to list all functions in a database
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_functions_query(database_name, schema_name)
  return string.format([[
SELECT
  routine_name AS name,
  routine_type AS type
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;
]], database_name)
end

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_columns_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  column_name AS column_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS `precision`,
  numeric_scale AS `scale`,
  is_nullable AS is_nullable,
  column_default AS default_value,
  extra AS extra,
  ordinal_position AS ordinal_position
FROM information_schema.columns
WHERE table_schema = '%s'
  AND table_name = '%s'
ORDER BY ordinal_position;
]], database_name, table_name)
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_indexes_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  index_name AS index_name,
  index_type AS index_type,
  non_unique AS non_unique,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS column_names
FROM information_schema.statistics
WHERE table_schema = '%s'
  AND table_name = '%s'
GROUP BY index_name, index_type, non_unique
ORDER BY index_name;
]], database_name, table_name)
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_constraints_query(database_name, schema_name, table_name)
  return string.format([[
SELECT
  tc.constraint_name AS constraint_name,
  tc.constraint_type AS constraint_type,
  GROUP_CONCAT(kcu.column_name ORDER BY kcu.ordinal_position) AS column_names,
  kcu.referenced_table_schema AS referenced_table_schema,
  kcu.referenced_table_name AS referenced_table_name,
  GROUP_CONCAT(kcu.referenced_column_name ORDER BY kcu.ordinal_position) AS referenced_columns
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
  AND tc.table_name = kcu.table_name
WHERE tc.table_schema = '%s'
  AND tc.table_name = '%s'
GROUP BY tc.constraint_name, tc.constraint_type, kcu.referenced_table_schema, kcu.referenced_table_name
ORDER BY tc.constraint_type, tc.constraint_name;
]], database_name, table_name)
end

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function MySQLAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  return string.format([[
SELECT
  parameter_name AS parameter_name,
  data_type AS data_type,
  character_maximum_length AS max_length,
  numeric_precision AS `precision`,
  numeric_scale AS `scale`,
  parameter_mode AS mode,
  ordinal_position AS ordinal_position
FROM information_schema.parameters
WHERE specific_schema = '%s'
  AND specific_name = '%s'
  AND routine_type = '%s'
ORDER BY ordinal_position;
]], database_name, routine_name, routine_type)
end

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function MySQLAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  if object_type == "VIEW" then
    return string.format([[
SELECT view_definition AS definition
FROM information_schema.views
WHERE table_schema = '%s'
  AND table_name = '%s';
]], database_name, object_name)
  else
    -- For procedures and functions
    return string.format([[
SELECT routine_definition AS definition
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_name = '%s';
]], database_name, object_name)
  end
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string
---@param schema_name string? Not used in MySQL
---@param table_name string
---@return string query
function MySQLAdapter:get_table_definition_query(database_name, schema_name, table_name)
  -- SHOW CREATE TABLE returns columns: 'Table' and 'Create Table'
  -- The 'Create Table' column contains the CREATE TABLE statement
  return string.format([[SHOW CREATE TABLE `%s`.`%s`;]], database_name, table_name)
end

---Parse table definition result and return normalized format
---@param result table Node.js result object
---@return string? definition The CREATE TABLE statement
function MySQLAdapter:parse_table_definition(result)
  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    if #rows > 0 then
      -- SHOW CREATE TABLE returns 'Create Table' column
      return rows[1]["Create Table"]
    end
  end
  return nil
end

-- parse_definition() inherited from BaseAdapter

-- ============================================================================
-- Bulk Loading Methods (for SSNSSearch)
-- ============================================================================

---Get query to retrieve ALL columns for ALL tables/views in a database (no schema filter)
---Used for bulk metadata loading in object search
---@param database_name string
---@return string query
function MySQLAdapter:get_all_columns_bulk_query(database_name)
  return string.format([[
SELECT
  c.table_name,
  CASE t.table_type WHEN 'BASE TABLE' THEN 'table' ELSE 'view' END AS object_type,
  c.column_name,
  c.data_type,
  c.ordinal_position AS sort_order
FROM information_schema.columns c
JOIN information_schema.tables t
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
WHERE c.table_schema = '%s'
ORDER BY c.table_name, c.ordinal_position;
]], database_name)
end

---Parse bulk columns result into metadata map
---@param result table Node.js result object
---@return table<string, string> metadata Map of "schema.object_type.name" -> "col1 type1 col2 type2 ..."
function MySQLAdapter:parse_all_columns_bulk(result)
  local metadata = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    -- Group columns by table
    local columns_by_table = {}
    for _, row in ipairs(rows) do
      if row.table_name and row.column_name then
        -- MySQL doesn't have schemas within database, use 'dbo' as placeholder for consistency
        local key = string.format("dbo.%s.%s", row.object_type or "table", row.table_name)
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

---Get query to retrieve ALL parameters for ALL procedures/functions in a database
---Used for bulk metadata loading in object search
---@param database_name string
---@return string query
function MySQLAdapter:get_all_parameters_bulk_query(database_name)
  return string.format([[
SELECT
  r.routine_name,
  LOWER(r.routine_type) AS object_type,
  p.parameter_name,
  p.data_type
FROM information_schema.parameters p
JOIN information_schema.routines r
  ON p.specific_schema = r.routine_schema
  AND p.specific_name = r.specific_name
WHERE p.specific_schema = '%s'
  AND p.parameter_name IS NOT NULL
ORDER BY r.routine_name, p.ordinal_position;
]], database_name)
end

---Parse bulk parameters result into metadata map
---@param result table Node.js result object
---@return table<string, string> metadata Map of "schema.object_type.name" -> "param1 type1 param2 type2 ..."
function MySQLAdapter:parse_all_parameters_bulk(result)
  local metadata = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    -- Group parameters by routine
    local params_by_routine = {}
    for _, row in ipairs(rows) do
      if row.routine_name and row.parameter_name then
        -- MySQL doesn't have schemas within database, use 'dbo' as placeholder
        local key = string.format("dbo.%s.%s", row.object_type or "function", row.routine_name)
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

---Get query to retrieve ALL definitions for views, procedures, functions in a database
---Note: MySQL's information_schema.routines.routine_definition may be NULL for security
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_all_definitions_bulk_query(database_name, schema_name)
  return string.format([[
-- Views
SELECT
  table_name AS object_name,
  'view' AS object_type,
  view_definition AS definition
FROM information_schema.views
WHERE table_schema = '%s'

UNION ALL

-- Procedures and Functions
SELECT
  routine_name AS object_name,
  LOWER(routine_type) AS object_type,
  routine_definition AS definition
FROM information_schema.routines
WHERE routine_schema = '%s'
  AND routine_definition IS NOT NULL;
]], database_name, database_name)
end

---Parse bulk definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.object_type.name" -> definition
function MySQLAdapter:parse_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.object_name and row.definition then
        -- MySQL doesn't have schemas within database, use 'dbo' as placeholder
        local key = string.format("dbo.%s.%s", row.object_type, row.object_name)
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
---Note: MySQL SHOW CREATE TABLE only works for one table at a time, so we build from information_schema
---@param database_name string
---@param schema_name string? Not used in MySQL
---@return string query
function MySQLAdapter:get_all_table_definitions_bulk_query(database_name, schema_name)
  return string.format([[
SELECT
  t.table_name,
  'table' AS object_type,
  CONCAT(
    'CREATE TABLE `', t.table_name, '` (\n',
    GROUP_CONCAT(
      CONCAT(
        '  `', c.column_name, '` ',
        UPPER(c.data_type),
        CASE
          WHEN c.character_maximum_length IS NOT NULL THEN CONCAT('(', c.character_maximum_length, ')')
          WHEN c.numeric_precision IS NOT NULL AND c.numeric_scale IS NOT NULL THEN CONCAT('(', c.numeric_precision, ',', c.numeric_scale, ')')
          ELSE ''
        END,
        CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END,
        CASE WHEN c.column_default IS NOT NULL THEN CONCAT(' DEFAULT ', c.column_default) ELSE '' END,
        CASE WHEN c.extra LIKE '%%auto_increment%%' THEN ' AUTO_INCREMENT' ELSE '' END
      )
      ORDER BY c.ordinal_position
      SEPARATOR ',\n'
    ),
    '\n);'
  ) AS definition
FROM information_schema.tables t
JOIN information_schema.columns c
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE t.table_schema = '%s'
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name;
]], database_name)
end

---Parse bulk table definitions result
---@param result table Node.js result object
---@return table<string, string> definitions Map of "schema.table.name" -> definition
function MySQLAdapter:parse_table_definitions_bulk(result)
  local definitions = {}

  if result and result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      if row.table_name and row.definition then
        -- MySQL doesn't have schemas within database, use 'dbo' as placeholder
        local key = string.format("dbo.table.%s", row.table_name)
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

-- parse_databases() inherited from BaseAdapter

---Parse table list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table tables
function MySQLAdapter:parse_tables(result)
  local tables = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(tables, {
        name = row.name,
        type = row.type,
      })
    end
  end
  return tables
end

---Parse view list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table views
function MySQLAdapter:parse_views(result)
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

---Parse procedure list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table procedures
function MySQLAdapter:parse_procedures(result)
  local procedures = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(procedures, {
        name = row.name,
      })
    end
  end
  return procedures
end

---Parse function list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table functions
function MySQLAdapter:parse_functions(result)
  local funcs = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(funcs, {
        name = row.name,
        type = row.type,
      })
    end
  end
  return funcs
end

---Parse column list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table columns
function MySQLAdapter:parse_columns(result)
  local columns = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      -- All column names aliased to lowercase in query for consistency
      table.insert(columns, {
        name = row.column_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.precision,
        scale = row.scale,
        nullable = row.is_nullable == "YES",
        is_identity = row.extra and row.extra:lower():find("auto_increment") ~= nil,
        is_computed = row.extra and (row.extra:lower():find("generated") ~= nil or row.extra:lower():find("virtual") ~= nil),
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
function MySQLAdapter:parse_indexes(result)
  local indexes = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(indexes, {
        name = row.index_name,
        type = row.index_type,
        is_unique = row.non_unique == 0,  -- MySQL specific: non_unique=0 means unique
        is_primary = row.index_name == "PRIMARY",  -- MySQL specific: PRIMARY index name
        columns = self:parse_column_list(row.column_names, ","),
      })
    end
  end
  return indexes
end

---Parse constraint list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table constraints
function MySQLAdapter:parse_constraints(result)
  local constraints = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      local ref_columns = self:parse_column_list(row.referenced_columns, ",")

      table.insert(constraints, {
        name = row.constraint_name,
        type = row.constraint_type,
        columns = self:parse_column_list(row.column_names, ","),
        referenced_table = self:safe_get(row.referenced_table_name),
        referenced_schema = self:safe_get(row.referenced_table_schema),
        referenced_columns = #ref_columns > 0 and ref_columns or nil,
      })
    end
  end
  return constraints
end

---Parse parameter list results
---@param result table Node.js result object { success, resultSets, metadata, error }
---@return table parameters
function MySQLAdapter:parse_parameters(result)
  local parameters = {}
  if result.success and result.resultSets and #result.resultSets > 0 then
    local rows = result.resultSets[1].rows or {}
    for _, row in ipairs(rows) do
      table.insert(parameters, {
        name = row.parameter_name,
        data_type = row.data_type,
        max_length = row.max_length,
        precision = row.precision,
        scale = row.scale,
        mode = row.mode or "IN",
        ordinal_position = row.ordinal_position,
      })
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
function MySQLAdapter:create_table(parent, row)
  local TableClass = require('nvim-ssns.classes.table')
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
function MySQLAdapter:create_view(parent, row)
  local ViewClass = require('nvim-ssns.classes.view')
  return ViewClass.new({
    name = row.name,
    parent = parent,
  })
end

---Create a procedure object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_procedure(parent, row)
  local ProcedureClass = require('nvim-ssns.classes.procedure')
  return ProcedureClass.new({
    name = row.name,
    parent = parent,
  })
end

---Create a function object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_function(parent, row)
  local FunctionClass = require('nvim-ssns.classes.function')
  return FunctionClass.new({
    name = row.name,
    function_type = row.type,
    parent = parent,
  })
end

---Create a column object from parsed row data
---@param parent BaseDbObject
---@param row table
---@return BaseDbObject
function MySQLAdapter:create_column(parent, row)
  local ColumnClass = require('nvim-ssns.classes.column')
  return ColumnClass.new({
    name = row.name,
    data_type = row.data_type,
    nullable = row.nullable,
    is_identity = row.is_identity,
    is_computed = row.is_computed,
    default = row.default,
    max_length = row.max_length,
    precision = row.precision,
    scale = row.scale,
    parent = parent,
  })
end

-- ============================================================================
-- Utility Methods
-- ============================================================================

---Get the identifier quote character for MySQL
---@return string
function MySQLAdapter:get_quote_char()
  return "`"  -- MySQL uses backticks
end

---Get a string representation for debugging
---@return string
function MySQLAdapter:to_string()
  local server_info = ""
  if self.connection_config and self.connection_config.server then
    server_info = self.connection_config.server.host or ""
    if self.connection_config.server.port then
      server_info = server_info .. ":" .. self.connection_config.server.port
    end
  end
  return string.format("MySQLAdapter{server=%s}", server_info)
end

return MySQLAdapter
