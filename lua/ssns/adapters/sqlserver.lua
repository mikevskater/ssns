local BaseAdapter = require('ssns.adapters.base')
local Metadata = require('ssns.adapters.sqlserver_metadata')

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

-- execute() and test_connection() inherited from BaseAdapter

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

-- ============================================================================
-- Metadata Query Delegations
-- ============================================================================

---Get query to list all columns in a table or view
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_columns_query(database_name, schema_name, table_name)
  return Metadata.get_columns_query(database_name, schema_name, table_name)
end

---Get query to bulk load all columns for all tables and views in a schema
---@param database_name string
---@param schema_name string
---@return string query
function SqlServerAdapter:get_columns_bulk_query(database_name, schema_name)
  return Metadata.get_columns_bulk_query(database_name, schema_name)
end

---Get query to retrieve ALL columns for ALL tables/views/TVFs in a database
---@param database_name string
---@return string query
function SqlServerAdapter:get_all_columns_bulk_query(database_name)
  return Metadata.get_all_columns_bulk_query(database_name)
end

---Get query to retrieve ALL parameters for ALL procedures/functions in a database
---@param database_name string
---@return string query
function SqlServerAdapter:get_all_parameters_bulk_query(database_name)
  return Metadata.get_all_parameters_bulk_query(database_name)
end

-- parse_all_columns_bulk() and parse_all_parameters_bulk() inherited from BaseAdapter

---Get query to list columns of a table-valued function (TVF)
---@param database_name string
---@param schema_name string?
---@param function_name string
---@return string query
function SqlServerAdapter:get_tvf_columns_query(database_name, schema_name, function_name)
  return Metadata.get_tvf_columns_query(database_name, schema_name, function_name)
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_indexes_query(database_name, schema_name, table_name)
  return Metadata.get_indexes_query(database_name, schema_name, table_name)
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_constraints_query(database_name, schema_name, table_name)
  return Metadata.get_constraints_query(database_name, schema_name, table_name)
end

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string?
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function SqlServerAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  return Metadata.get_parameters_query(database_name, schema_name, routine_name, routine_type)
end

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string?
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function SqlServerAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  return Metadata.get_definition_query(database_name, schema_name, object_name, object_type)
end

---Get query to retrieve the CREATE TABLE script for a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function SqlServerAdapter:get_table_definition_query(database_name, schema_name, table_name)
  return Metadata.get_table_definition_query(database_name, schema_name, table_name)
end

-- parse_table_definition() and parse_definition() inherited from BaseAdapter

---Get query to retrieve ALL definitions for views, procedures, functions in a database
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function SqlServerAdapter:get_all_definitions_bulk_query(database_name, schema_name)
  return Metadata.get_all_definitions_bulk_query(database_name, schema_name)
end

-- parse_definitions_bulk() inherited from BaseAdapter

---Get query to retrieve CREATE TABLE scripts for ALL tables in a database
---@param database_name string
---@param schema_name string? Optional schema filter
---@return string query
function SqlServerAdapter:get_all_table_definitions_bulk_query(database_name, schema_name)
  return Metadata.get_all_table_definitions_bulk_query(database_name, schema_name)
end

-- parse_table_definitions_bulk() inherited from BaseAdapter

---Get query to fetch object dependencies
---@param database_name string
---@param schema_name string
---@param object_name string
---@return string query
function SqlServerAdapter:get_dependencies_query(database_name, schema_name, object_name)
  return Metadata.get_dependencies_query(database_name, schema_name, object_name)
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

-- parse_databases() and parse_schemas() inherited from BaseAdapter

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
