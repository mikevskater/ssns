---@class AdapterFeatures
---@field schemas boolean Whether this database supports schemas (SQL Server, PostgreSQL yes; MySQL, SQLite no)
---@field synonyms boolean Whether this database supports synonyms (SQL Server yes; others no)
---@field procedures boolean Whether this database supports stored procedures
---@field functions boolean Whether this database supports user-defined functions
---@field sequences boolean Whether this database supports sequences (PostgreSQL, Oracle yes; SQL Server 2012+)
---@field triggers boolean Whether this database supports triggers
---@field views boolean Whether this database supports views
---@field indexes boolean Whether this database supports indexes
---@field constraints boolean Whether this database supports constraints (PK, FK, etc.)

---@class BaseAdapter
---@field db_type string The database type identifier (e.g., "sqlserver", "postgres", "mysql")
---@field features AdapterFeatures Feature flags for this database type
---@field connection_config ConnectionData The connection configuration for this database
local BaseAdapter = {}
BaseAdapter.__index = BaseAdapter

---Create a new adapter instance
---@param db_type string
---@param connection_config ConnectionData
---@return BaseAdapter
function BaseAdapter.new(db_type, connection_config)
  local self = setmetatable({}, BaseAdapter)

  self.db_type = db_type
  self.connection_config = connection_config

  -- Default features (subclasses override)
  self.features = {
    schemas = false,
    synonyms = false,
    procedures = true,
    functions = true,
    sequences = false,
    triggers = true,
    views = true,
    indexes = true,
    constraints = true,
  }

  return self
end

---Execute a query against the database (synchronous)
---@param connection any The database connection object
---@param query string The SQL query to execute
---@return table results Array of result rows
function BaseAdapter:execute(connection, query)
  error("BaseAdapter:execute() must be implemented by subclass")
end

---Test if the connection is valid
---@param connection any The database connection object
---@return boolean success
---@return string? error_message
function BaseAdapter:test_connection(connection)
  error("BaseAdapter:test_connection() must be implemented by subclass")
end

-- ============================================================================
-- Database Object Queries
-- ============================================================================

---Get query to list all databases on the server
---@return string query
function BaseAdapter:get_databases_query()
  error("BaseAdapter:get_databases_query() must be implemented by subclass")
end

---Get query to list all schemas in a database
---@param database_name string
---@return string query
function BaseAdapter:get_schemas_query(database_name)
  error("BaseAdapter:get_schemas_query() must be implemented by subclass")
end

---Get query to list all tables in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_tables_query(database_name, schema_name)
  error("BaseAdapter:get_tables_query() must be implemented by subclass")
end

---Get query to list all views in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_views_query(database_name, schema_name)
  error("BaseAdapter:get_views_query() must be implemented by subclass")
end

---Get query to list all stored procedures in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_procedures_query(database_name, schema_name)
  error("BaseAdapter:get_procedures_query() must be implemented by subclass")
end

---Get query to list all functions in a schema
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_functions_query(database_name, schema_name)
  error("BaseAdapter:get_functions_query() must be implemented by subclass")
end

---Get query to list all synonyms in a schema (SQL Server specific)
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_synonyms_query(database_name, schema_name)
  -- Default: not supported
  return ""
end

---Get query to list all sequences in a schema (PostgreSQL, Oracle)
---@param database_name string
---@param schema_name string?
---@return string query
function BaseAdapter:get_sequences_query(database_name, schema_name)
  -- Default: not supported
  return ""
end

---Get query to list all columns in a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function BaseAdapter:get_columns_query(database_name, schema_name, table_name)
  error("BaseAdapter:get_columns_query() must be implemented by subclass")
end

---Get query to list all indexes on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function BaseAdapter:get_indexes_query(database_name, schema_name, table_name)
  error("BaseAdapter:get_indexes_query() must be implemented by subclass")
end

---Get query to list all constraints on a table
---@param database_name string
---@param schema_name string?
---@param table_name string
---@return string query
function BaseAdapter:get_constraints_query(database_name, schema_name, table_name)
  error("BaseAdapter:get_constraints_query() must be implemented by subclass")
end

---Get query to list all parameters for a procedure/function
---@param database_name string
---@param schema_name string?
---@param routine_name string
---@param routine_type string "PROCEDURE" or "FUNCTION"
---@return string query
function BaseAdapter:get_parameters_query(database_name, schema_name, routine_name, routine_type)
  error("BaseAdapter:get_parameters_query() must be implemented by subclass")
end

---Get query to retrieve the definition of a view/procedure/function
---@param database_name string
---@param schema_name string?
---@param object_name string
---@param object_type string "VIEW", "PROCEDURE", or "FUNCTION"
---@return string query
function BaseAdapter:get_definition_query(database_name, schema_name, object_name, object_type)
  error("BaseAdapter:get_definition_query() must be implemented by subclass")
end

-- ============================================================================
-- Result Parsing Methods
-- ============================================================================

---Parse database list results into structured data
---@param results table Raw query results
---@return table databases Array of {name: string}
function BaseAdapter:parse_databases(results)
  error("BaseAdapter:parse_databases() must be implemented by subclass")
end

---Parse schema list results into structured data
---@param results table Raw query results
---@return table schemas Array of {name: string}
function BaseAdapter:parse_schemas(results)
  error("BaseAdapter:parse_schemas() must be implemented by subclass")
end

---Parse table list results into structured data
---@param results table Raw query results
---@return table tables Array of {schema: string?, name: string, type: string?}
function BaseAdapter:parse_tables(results)
  error("BaseAdapter:parse_tables() must be implemented by subclass")
end

---Parse view list results into structured data
---@param results table Raw query results
---@return table views Array of {schema: string?, name: string}
function BaseAdapter:parse_views(results)
  error("BaseAdapter:parse_views() must be implemented by subclass")
end

---Parse procedure list results into structured data
---@param results table Raw query results
---@return table procedures Array of {schema: string?, name: string}
function BaseAdapter:parse_procedures(results)
  error("BaseAdapter:parse_procedures() must be implemented by subclass")
end

---Parse function list results into structured data
---@param results table Raw query results
---@return table functions Array of {schema: string?, name: string}
function BaseAdapter:parse_functions(results)
  error("BaseAdapter:parse_functions() must be implemented by subclass")
end

---Parse column list results into structured data
---@param results table Raw query results
---@return table columns Array of {name: string, data_type: string, nullable: boolean, default: string?, max_length: number?, precision: number?, scale: number?}
function BaseAdapter:parse_columns(results)
  error("BaseAdapter:parse_columns() must be implemented by subclass")
end

---Parse index list results into structured data
---@param results table Raw query results
---@return table indexes Array of {name: string, columns: string[], is_unique: boolean, is_primary: boolean}
function BaseAdapter:parse_indexes(results)
  error("BaseAdapter:parse_indexes() must be implemented by subclass")
end

---Parse constraint list results into structured data
---@param results table Raw query results
---@return table constraints Array of {name: string, type: string, columns: string[], referenced_table: string?, referenced_columns: string[]?}
function BaseAdapter:parse_constraints(results)
  error("BaseAdapter:parse_constraints() must be implemented by subclass")
end

---Parse parameter list results into structured data
---@param results table Raw query results
---@return table parameters Array of {name: string, data_type: string, mode: string, default: string?}
function BaseAdapter:parse_parameters(results)
  error("BaseAdapter:parse_parameters() must be implemented by subclass")
end

-- ============================================================================
-- Object Creation Helpers
-- ============================================================================

---Create a table object from parsed row data
---@param parent BaseDbObject The parent schema object
---@param row table Parsed table row data
---@return BaseDbObject table_object
function BaseAdapter:create_table(parent, row)
  error("BaseAdapter:create_table() must be implemented by subclass")
end

---Create a view object from parsed row data
---@param parent BaseDbObject The parent schema object
---@param row table Parsed view row data
---@return BaseDbObject view_object
function BaseAdapter:create_view(parent, row)
  error("BaseAdapter:create_view() must be implemented by subclass")
end

---Create a column object from parsed row data
---@param parent BaseDbObject The parent table/view object
---@param row table Parsed column row data
---@return BaseDbObject column_object
function BaseAdapter:create_column(parent, row)
  error("BaseAdapter:create_column() must be implemented by subclass")
end

-- ============================================================================
-- Parsing Utility Methods
-- ============================================================================

---Safely get a value, handling vim.NIL and nil
---@param value any The value to check
---@param default any? Default value if nil/vim.NIL (default: nil)
---@return any value The value or default
function BaseAdapter:safe_get(value, default)
  if value == nil or value == vim.NIL then
    return default
  end
  return value
end

---Convert a value to boolean, handling various representations
---Handles: true/false, 1/0, "1"/"0", "true"/"false", "yes"/"no", vim.NIL
---@param value any The value to convert
---@param default boolean? Default if nil/vim.NIL (default: false)
---@return boolean
function BaseAdapter:to_boolean(value, default)
  default = default or false

  if value == nil or value == vim.NIL then
    return default
  end

  if type(value) == "boolean" then
    return value
  end

  if type(value) == "number" then
    return value ~= 0
  end

  if type(value) == "string" then
    local lower = value:lower()
    -- Handle: true/yes/1/t (PostgreSQL uses t/f)
    return lower == "true" or lower == "yes" or lower == "1" or lower == "t"
  end

  return default
end

---Parse a comma-separated column list string into array
---Handles vim.NIL and empty strings
---@param value any The value (string or vim.NIL)
---@param separator string? Separator pattern (default: ", ")
---@return string[] columns Array of column names (empty if nil/invalid)
function BaseAdapter:parse_column_list(value, separator)
  separator = separator or ", "

  if value == nil or value == vim.NIL or value == "" then
    return {}
  end

  if type(value) ~= "string" then
    return {}
  end

  return vim.split(value, separator, { plain = true })
end

---Normalize line endings in text (convert \r\n to \n)
---@param text any The text to normalize
---@return string? normalized Normalized text or nil
function BaseAdapter:normalize_line_endings(text)
  if text == nil or text == vim.NIL then
    return nil
  end

  if type(text) ~= "string" then
    return nil
  end

  return text:gsub("\r\n", "\n"):gsub("\r", "\n")
end

---Safe number conversion handling vim.NIL
---@param value any The value to convert
---@param default number? Default if nil/vim.NIL (default: nil)
---@return number?
function BaseAdapter:to_number(value, default)
  if value == nil or value == vim.NIL then
    return default
  end

  if type(value) == "number" then
    return value
  end

  if type(value) == "string" then
    return tonumber(value) or default
  end

  return default
end

---Get a string value safely, handling vim.NIL
---@param value any The value
---@param default string? Default if nil/vim.NIL (default: "")
---@return string
function BaseAdapter:to_string_safe(value, default)
  default = default or ""

  if value == nil or value == vim.NIL then
    return default
  end

  return tostring(value)
end

-- ============================================================================
-- Identifier Utility Methods
-- ============================================================================

---Get the identifier quote character for this database
---@return string quote_char The character used to quote identifiers (e.g., "[" for SQL Server, "\"" for PostgreSQL)
function BaseAdapter:get_quote_char()
  error("BaseAdapter:get_quote_char() must be implemented by subclass")
end


---Check if an identifier needs quoting
---@param identifier string The identifier to check
---@return boolean needs_quoting True if the identifier needs to be quoted
function BaseAdapter:needs_quoting(identifier)
  if not identifier or identifier == "" then
    return false
  end

  -- Check if it starts with a digit
  if identifier:match("^%d") then
    return true
  end

  -- Check if it contains anything other than alphanumeric and underscore
  -- Pattern: if it contains characters NOT in [a-zA-Z0-9_], it needs quoting
  if identifier:match("[^%w_]") then
    return true
  end

  return false
end

---Quote an identifier (table name, column name, etc.) only if needed
---@param identifier string
---@param force boolean? Force quoting even if not needed (default: false)
---@return string quoted_or_plain
function BaseAdapter:quote_identifier(identifier, force)
  -- Check config setting for always quoting
  local Config = require('ssns.config')
  local always_quote = Config.get_completion().always_quote_identifiers

  -- Only quote if needed (or forced, or always_quote is enabled)
  if not force and not always_quote and not self:needs_quoting(identifier) then
    return identifier
  end

  local quote = self:get_quote_char()
  if quote == "[" then
    -- SQL Server style [name]
    return "[" .. identifier .. "]"
  else
    -- Standard SQL style "name" or `name`
    return quote .. identifier .. quote
  end
end

---Build a fully qualified object name
---@param database_name string?
---@param schema_name string?
---@param object_name string
---@return string qualified_name
function BaseAdapter:get_qualified_name(database_name, schema_name, object_name)
  local parts = {}

  if database_name and database_name ~= "" then
    table.insert(parts, self:quote_identifier(database_name))
  end

  if self.features.schemas and schema_name and schema_name ~= "" then
    table.insert(parts, self:quote_identifier(schema_name))
  end

  table.insert(parts, self:quote_identifier(object_name))

  return table.concat(parts, ".")
end

---Get a string representation for debugging
---@return string
function BaseAdapter:to_string()
  return string.format("BaseAdapter{db_type=%s}", self.db_type)
end

return BaseAdapter
