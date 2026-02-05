---@class Factory
---Factory for creating database objects
---Centralizes object creation logic and provides consistent instantiation
local Factory = {}

---Create a Server instance from connection configuration
---@param name string Display name for the server
---@param connection_config ConnectionData Database connection configuration
---@return ServerClass server The created server instance
---@return string? error_message Error message if creation failed
function Factory.create_server(name, connection_config)
  local ServerClass = require('nvim-ssns.classes.server')

  local server = ServerClass.new({
    name = name,
    connection_config = connection_config,
  })

  if server.connection_state == ServerClass.ConnectionState.ERROR then
    return server, server.error_message
  end

  return server, nil
end

---Create a Database instance
---@param name string Database name
---@param parent ServerClass Parent server object
---@return DbClass database The created database instance
function Factory.create_database(name, parent)
  local DbClass = require('nvim-ssns.classes.database')

  return DbClass.new({
    name = name,
    parent = parent,
  })
end

---Create a Schema instance
---@param name string Schema name
---@param parent DbClass Parent database object
---@return SchemaClass schema The created schema instance
function Factory.create_schema(name, parent)
  local SchemaClass = require('nvim-ssns.classes.schema')

  return SchemaClass.new({
    name = name,
    parent = parent,
  })
end

---Create a Table instance
---@param name string Table name
---@param schema_name string Schema name
---@param table_type string? Table type
---@param parent SchemaClass Parent schema object
---@return TableClass table The created table instance
function Factory.create_table(name, schema_name, table_type, parent)
  local TableClass = require('nvim-ssns.classes.table')

  return TableClass.new({
    name = name,
    schema_name = schema_name,
    table_type = table_type,
    parent = parent,
  })
end

---Create a View instance
---@param name string View name
---@param schema_name string Schema name
---@param parent SchemaClass Parent schema object
---@return ViewClass view The created view instance
function Factory.create_view(name, schema_name, parent)
  local ViewClass = require('nvim-ssns.classes.view')

  return ViewClass.new({
    name = name,
    schema_name = schema_name,
    parent = parent,
  })
end

---Create a Procedure instance
---@param name string Procedure name
---@param schema_name string Schema name
---@param parent SchemaClass Parent schema object
---@return ProcedureClass procedure The created procedure instance
function Factory.create_procedure(name, schema_name, parent)
  local ProcedureClass = require('nvim-ssns.classes.procedure')

  return ProcedureClass.new({
    name = name,
    schema_name = schema_name,
    parent = parent,
  })
end

---Create a Function instance
---@param name string Function name
---@param schema_name string Schema name
---@param function_type string? Function type
---@param parent SchemaClass Parent schema object
---@return FunctionClass function The created function instance
function Factory.create_function(name, schema_name, function_type, parent)
  local FunctionClass = require('nvim-ssns.classes.function')

  return FunctionClass.new({
    name = name,
    schema_name = schema_name,
    function_type = function_type,
    parent = parent,
  })
end

---Create a Column instance
---@param name string Column name
---@param data_type string Data type
---@param nullable boolean Whether NULL is allowed
---@param parent TableClass|ViewClass Parent table or view object
---@param opts table? Additional options (is_identity, default, max_length, precision, scale)
---@return ColumnClass column The created column instance
function Factory.create_column(name, data_type, nullable, parent, opts)
  local ColumnClass = require('nvim-ssns.classes.column')

  opts = opts or {}

  return ColumnClass.new({
    name = name,
    data_type = data_type,
    nullable = nullable,
    is_identity = opts.is_identity,
    default = opts.default,
    max_length = opts.max_length,
    precision = opts.precision,
    scale = opts.scale,
    ordinal_position = opts.ordinal_position,
    parent = parent,
  })
end

---Create an Index instance
---@param name string Index name
---@param columns string[] Column names in the index
---@param parent TableClass Parent table object
---@param opts table? Additional options (index_type, is_unique, is_primary)
---@return IndexClass index The created index instance
function Factory.create_index(name, columns, parent, opts)
  local IndexClass = require('nvim-ssns.classes.index')

  opts = opts or {}

  return IndexClass.new({
    name = name,
    columns = columns,
    index_type = opts.index_type,
    is_unique = opts.is_unique or false,
    is_primary = opts.is_primary or false,
    parent = parent,
  })
end

---Create a Constraint instance
---@param name string Constraint name
---@param constraint_type string Constraint type
---@param columns string[] Column names
---@param parent TableClass Parent table object
---@param opts table? Additional options (referenced_table, referenced_schema, referenced_columns, check_clause)
---@return ConstraintClass constraint The created constraint instance
function Factory.create_constraint(name, constraint_type, columns, parent, opts)
  local ConstraintClass = require('nvim-ssns.classes.constraint')

  opts = opts or {}

  return ConstraintClass.new({
    name = name,
    constraint_type = constraint_type,
    columns = columns,
    referenced_table = opts.referenced_table,
    referenced_schema = opts.referenced_schema,
    referenced_columns = opts.referenced_columns,
    check_clause = opts.check_clause,
    parent = parent,
  })
end

---Create a Parameter instance
---@param name string Parameter name
---@param data_type string Data type
---@param mode string Parameter mode (IN/OUT/INOUT)
---@param parent ProcedureClass|FunctionClass Parent procedure or function object
---@param opts table? Additional options (has_default, max_length, precision, scale)
---@return ParameterClass parameter The created parameter instance
function Factory.create_parameter(name, data_type, mode, parent, opts)
  local ParameterClass = require('nvim-ssns.classes.parameter')

  opts = opts or {}

  return ParameterClass.new({
    name = name,
    data_type = data_type,
    mode = mode,
    has_default = opts.has_default or false,
    max_length = opts.max_length,
    precision = opts.precision,
    scale = opts.scale,
    ordinal_position = opts.ordinal_position,
    parent = parent,
  })
end

---Clone a server configuration with a new connection
---Useful for creating multiple connections to the same server
---@param source_server ServerClass The source server to clone
---@param new_name string New display name
---@return ServerClass cloned_server The cloned server instance
function Factory.clone_server(source_server, new_name)
  local ServerClass = require('nvim-ssns.classes.server')

  local cloned = ServerClass.new({
    name = new_name,
    connection_config = vim.deepcopy(source_server.connection_config),
  })

  return cloned
end

---Validate a connection config
---@param connection_config ConnectionData
---@return boolean valid
---@return string? error_message
function Factory.validate_connection_config(connection_config)
  if not connection_config then
    return false, "Connection config is nil"
  end

  if not connection_config.type or connection_config.type == "" then
    return false, "Database type is required"
  end

  -- Check if adapter exists for this database type
  local AdapterFactory = require('nvim-ssns.adapters.factory')
  if not AdapterFactory.is_supported(connection_config.type) then
    return false, string.format("No adapter available for database type: %s", connection_config.type)
  end

  if not connection_config.server or not connection_config.server.host then
    return false, "Server host is required"
  end

  return true, nil
end

---Create a test server (for development/testing)
---@return ServerClass server Test server instance
function Factory.create_test_server()
  local test_config = {
    name = "Test Server",
    type = "sqlserver",
    server = {
      host = "localhost",
      database = "vim_dadbod_test",
    },
    auth = {
      type = "windows",
    },
    options = {},
    favorite = false,
    auto_connect = false,
  }

  local server = Factory.create_server("Test Server", test_config)
  return server
end

return Factory
