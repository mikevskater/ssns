local BaseDbObject = require('ssns.classes.base')

---@class TableClass : BaseDbObject
---@field table_name string The table name
---@field schema_name string The schema name
---@field table_type string? The table type (e.g., "BASE TABLE", "USER TABLE")
---@field parent SchemaClass The parent schema object
---@field columns ColumnClass[]? Array of column objects
---@field indexes IndexClass[]? Array of index objects
---@field constraints ConstraintClass[]? Array of constraint objects
---@field columns_loaded boolean Whether columns have been loaded
---@field indexes_loaded boolean Whether indexes have been loaded
---@field constraints_loaded boolean Whether constraints have been loaded
---@field definition string? The table definition SQL (CREATE TABLE script)
---@field definition_loaded boolean Whether definition has been loaded
local TableClass = setmetatable({}, { __index = BaseDbObject })
TableClass.__index = TableClass

---Create a new Table instance
---@param opts {name: string, schema_name: string, table_type: string?, parent: SchemaClass}
---@return TableClass
function TableClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), TableClass)

  self.object_type = "table"
  self.table_name = opts.name
  self.schema_name = opts.schema_name
  self.table_type = opts.table_type
  self.columns = nil
  self.indexes = nil
  self.constraints = nil
  self.columns_loaded = false
  self.indexes_loaded = false
  self.constraints_loaded = false
  self.definition = nil
  self.definition_loaded = false

  -- Set appropriate icon for table

  return self
end

---Get display name with schema prefix (e.g., [dbo].[TableName])
---@return string display_name
function TableClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.table_name)
  end
  return self.table_name
end

---Load table children (columns, indexes, constraints) - lazy loading
---@return boolean success
function TableClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes and detail groups for UI
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI (SELECT, DROP, etc.)
function TableClass:create_action_nodes()
  self:clear_children()

  -- Actions
  self:add_action("SELECT", "select")

  -- Lazy-loaded groups
  self:add_lazy_group("Columns", "column_group", function()
    self:load_columns()
    return self.columns
  end)

  self:add_lazy_group("Indexes", "index_group", function()
    self:load_indexes()
    return self.indexes
  end)

  self:add_lazy_group("Keys", "key_group", function()
    self:load_constraints()
    return self.constraints
  end)

  -- More actions
  self:add_action("ALTER", "alter")
  self:add_action("DROP", "drop")
  self:add_action("DEPENDENCIES", "dependencies")

  -- Actions group with table helpers
  self:add_actions_group({
    { "COUNT", "count" },
    { "DESCRIBE", "describe" },
    { "INSERT", "insert" },
    { "UPDATE", "update" },
    { "DELETE", "delete" },
  })
end

---Load columns for this table (lazy loading)
---@return ColumnClass[]
function TableClass:load_columns()
  if self.columns_loaded then
    return self.columns
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Validate we have a database
  if not db then
    vim.notify(string.format("SSNS: Table %s has no parent database", self.table_name), vim.log.levels.ERROR)
    self.columns = {}
    self.columns_loaded = true
    return self.columns
  end

  if not db.db_name then
    vim.notify(string.format("SSNS: Table %s parent '%s' is not a database (type: %s)",
      self.table_name,
      db.name or "unknown",
      db.object_type or "unknown"), vim.log.levels.ERROR)
    self.columns = {}
    self.columns_loaded = true
    return self.columns
  end

  -- Get columns query from adapter
  local query = adapter:get_columns_query(db.db_name, self.schema_name, self.table_name)

  -- Execute query
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Check for errors
  if results.error then
    vim.notify(string.format("SSNS: Error loading columns: %s", results.error.message or vim.inspect(results.error)), vim.log.levels.ERROR)
  end

  -- Parse results
  local columns = adapter:parse_columns(results)

  -- Create column objects (don't set parent to avoid adding to table's children)
  self.columns = {}
  for _, col_data in ipairs(columns) do
    local col_obj = adapter:create_column(nil, col_data)
    table.insert(self.columns, col_obj)
  end

  self.columns_loaded = true
  return self.columns
end

---Load indexes for this table (lazy loading)
---@return IndexClass[]
function TableClass:load_indexes()
  if self.indexes_loaded then
    return self.indexes
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Validate we have a database
  if not db then
    vim.notify(string.format("SSNS: Table %s has no parent database", self.table_name), vim.log.levels.ERROR)
    self.indexes = {}
    self.indexes_loaded = true
    return self.indexes
  end

  if not db.db_name then
    vim.notify(string.format("SSNS: Table %s parent '%s' is not a database (type: %s)",
      self.table_name,
      db.name or "unknown",
      db.object_type or "unknown"), vim.log.levels.ERROR)
    self.indexes = {}
    self.indexes_loaded = true
    return self.indexes
  end

  -- Get indexes query from adapter
  local query = adapter:get_indexes_query(db.db_name, self.schema_name, self.table_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Parse results
  local indexes = adapter:parse_indexes(results)

  -- Create index objects (don't set parent to avoid adding to table's children)
  self.indexes = {}
  for _, idx_data in ipairs(indexes) do
    local IndexClass = require('ssns.classes.index')
    local idx_obj = IndexClass.new({
      name = idx_data.name,
      index_type = idx_data.type,
      is_unique = idx_data.is_unique,
      is_primary = idx_data.is_primary,
      columns = idx_data.columns,
      parent = nil,
    })
    table.insert(self.indexes, idx_obj)
  end

  self.indexes_loaded = true
  return self.indexes
end

---Load constraints for this table (lazy loading)
---@return ConstraintClass[]
function TableClass:load_constraints()
  if self.constraints_loaded then
    return self.constraints
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Validate we have a database
  if not db then
    vim.notify(string.format("SSNS: Table %s has no parent database", self.table_name), vim.log.levels.ERROR)
    self.constraints = {}
    self.constraints_loaded = true
    return self.constraints
  end

  if not db.db_name then
    vim.notify(string.format("SSNS: Table %s parent '%s' is not a database (type: %s)",
      self.table_name,
      db.name or "unknown",
      db.object_type or "unknown"), vim.log.levels.ERROR)
    self.constraints = {}
    self.constraints_loaded = true
    return self.constraints
  end

  -- Get constraints query from adapter
  local query = adapter:get_constraints_query(db.db_name, self.schema_name, self.table_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Parse results
  local constraints = adapter:parse_constraints(results)

  -- Create constraint objects (don't set parent to avoid adding to table's children)
  self.constraints = {}
  for _, constraint_data in ipairs(constraints) do
    local ConstraintClass = require('ssns.classes.constraint')
    local constraint_obj = ConstraintClass.new({
      name = constraint_data.name,
      constraint_type = constraint_data.type,
      columns = constraint_data.columns,
      referenced_table = constraint_data.referenced_table,
      referenced_schema = constraint_data.referenced_schema,
      referenced_columns = constraint_data.referenced_columns,
      parent = nil,
    })
    table.insert(self.constraints, constraint_obj)
  end

  self.constraints_loaded = true
  return self.constraints
end

---Get columns (load if not already loaded)
---@return ColumnClass[]
function TableClass:get_columns()
  if not self.columns_loaded then
    self:load_columns()
  end
  return self.columns
end

---Get indexes (load if not already loaded)
---@return IndexClass[]
function TableClass:get_indexes()
  if not self.indexes_loaded then
    self:load_indexes()
  end
  return self.indexes
end

---Get constraints (load if not already loaded)
---@return ConstraintClass[]
function TableClass:get_constraints()
  if not self.constraints_loaded then
    self:load_constraints()
  end
  return self.constraints
end

---Find a column by name
---@param column_name string
---@return ColumnClass?
function TableClass:find_column(column_name)
  local columns = self:get_columns()

  for _, col in ipairs(columns) do
    if col.name == column_name then
      return col
    end
  end

  return nil
end

---Generate a SELECT statement for this table
---@param top number? Optional TOP/LIMIT clause
---@return string sql
function TableClass:generate_select(top)
  local adapter = self:get_adapter()

  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  if top then
    if adapter.db_type == "sqlserver" then
      return string.format("SELECT TOP %d * FROM %s;", top, qualified_name)
    elseif adapter.db_type == "postgres" or adapter.db_type == "mysql" or adapter.db_type == "sqlite" then
      return string.format("SELECT * FROM %s LIMIT %d;", qualified_name, top)
    end
  end

  return string.format("SELECT * FROM %s;", qualified_name)
end

---Generate an INSERT statement template for this table
---@return string sql
function TableClass:generate_insert()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  local columns = self:get_columns()
  local column_names = {}
  local value_placeholders = {}

  for _, col in ipairs(columns) do
    -- Skip identity columns
    if not col.is_identity then
      table.insert(column_names, adapter:quote_identifier(col.name))
      table.insert(value_placeholders, "?")
    end
  end

  return string.format(
    "INSERT INTO %s (%s)\nVALUES (%s);",
    qualified_name,
    table.concat(column_names, ", "),
    table.concat(value_placeholders, ", ")
  )
end

---Generate a DROP statement for this table
---@return string sql
function TableClass:generate_drop()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  return string.format("DROP TABLE %s;", qualified_name)
end

---Generate a COUNT query for this table
---@return string sql
function TableClass:generate_count()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  return string.format("SELECT COUNT(*) AS row_count FROM %s;", qualified_name)
end

---Generate a DESCRIBE query for this table (sp_help for SQL Server)
---@return string sql
function TableClass:generate_describe()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  if adapter.db_type == "sqlserver" then
    return string.format("EXEC sp_help '%s.%s';", self.schema_name, self.table_name)
  else
    -- For other databases, just show columns
    return string.format("DESCRIBE %s;", qualified_name)
  end
end

---Generate an UPDATE statement template for this table
---@return string sql
function TableClass:generate_update()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  local columns = self:get_columns()

  if #columns == 0 then
    return string.format("-- No columns found for %s", qualified_name)
  end

  -- Build SET clause (skip identity columns)
  local set_parts = {}
  for _, col in ipairs(columns) do
    if not col.is_identity then
      table.insert(set_parts, string.format("  %s = ?", col.column_name or col.name))
    end
  end

  local sql = string.format("UPDATE %s\nSET\n%s\nWHERE -- Add your WHERE clause here\n  ?;",
    qualified_name,
    table.concat(set_parts, ",\n")
  )

  return sql
end

---Generate a DELETE statement template for this table
---@return string sql
function TableClass:generate_delete()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  return string.format("DELETE FROM %s\nWHERE -- Add your WHERE clause here\n  ?;", qualified_name)
end

---Get the full qualified name for this table
---@return string
function TableClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.table_name
  )
end

---Load the table definition (CREATE TABLE script)
---@return string? definition The CREATE TABLE script
function TableClass:load_definition()
  if self.definition_loaded then
    return self.definition
  end

  local adapter = self:get_adapter()

  -- Navigate to database based on server type:
  -- Schema-based (SQL Server, PostgreSQL): Table -> Schema -> Database
  -- Non-schema (MySQL, SQLite): Table -> Database
  local db
  if adapter.features.schemas then
    db = self.parent.parent  -- Table -> Schema -> Database
  else
    db = self.parent  -- Table -> Database
  end

  -- Validate we have a database
  if not db or not db.db_name then
    self.definition = string.format("-- Error: Unable to get definition for table %s", self.table_name)
    self.definition_loaded = true
    return self.definition
  end

  -- Use adapter to get the definition query
  local query = adapter:get_table_definition_query(db.db_name, self.schema_name, self.table_name)

  -- Execute query to get the definition
  local server = self:get_server()
  local success, results = pcall(adapter.execute, adapter, server.connection_config, query, { use_delimiter = false })

  if not success then
    self.definition = string.format("-- Error getting definition: %s", tostring(results))
    self.definition_loaded = true
    return self.definition
  end

  -- Use adapter's parse method for consistent result handling
  local definition = adapter:parse_table_definition(results)
  if definition then
    self.definition = definition
  else
    -- Fallback: construct CREATE TABLE from columns metadata
    self.definition = self:construct_create_table_from_metadata()
  end

  self.definition_loaded = true
  return self.definition
end

---Get the table definition (load if not already loaded)
---@return string? definition The CREATE TABLE script
function TableClass:get_definition()
  if not self.definition_loaded then
    self:load_definition()
  end
  return self.definition
end

---Construct a CREATE TABLE script from metadata (fallback)
---@return string sql The CREATE TABLE script
function TableClass:construct_create_table_from_metadata()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.table_name
  )

  local columns = self:get_columns()

  if #columns == 0 then
    return string.format("-- No columns found for %s", qualified_name)
  end

  local lines = {
    string.format("CREATE TABLE %s (", qualified_name)
  }

  -- Add column definitions
  for i, col in ipairs(columns) do
    local col_name = col.column_name or col.name
    local data_type = col.data_type or "VARCHAR(MAX)"
    local nullable = col.is_nullable and "NULL" or "NOT NULL"
    local identity = col.is_identity and " IDENTITY(1,1)" or ""
    local default_val = col.default_value and string.format(" DEFAULT %s", col.default_value) or ""

    local col_def = string.format("  %s %s%s %s%s",
      adapter:quote_identifier(col_name),
      data_type,
      identity,
      nullable,
      default_val
    )

    if i < #columns then
      col_def = col_def .. ","
    end

    table.insert(lines, col_def)
  end

  table.insert(lines, ");")

  return table.concat(lines, "\n")
end

---Get string representation for debugging
---@return string
function TableClass:to_string()
  return string.format(
    "TableClass{name=%s, schema=%s, columns=%d, indexes=%d}",
    self.name,
    self.schema_name,
    self.columns and #self.columns or 0,
    self.indexes and #self.indexes or 0
  )
end

---Get metadata info for display in floating window
---@return table metadata Standardized metadata structure with sections
function TableClass:get_metadata_info()
  local columns = self:get_columns()
  local rows = {}

  for _, col in ipairs(columns or {}) do
    local name = col.column_name or col.name or ""
    local full_type = col.get_full_type and col:get_full_type() or col.data_type or ""
    local nullable = "YES"
    if col.is_nullable == false or col.nullable == false then
      nullable = "NO"
    end
    local default_val = col.default_value or col.default or "-"

    table.insert(rows, {name, full_type, nullable, default_val})
  end

  return {
    sections = {
      {
        title = "COLUMNS",
        headers = {"Name", "Type", "Nullable", "Default"},
        rows = rows,
      },
    },
  }
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class TableLoadAsyncOpts : ExecutorOpts
---@field on_complete fun(result: any, error: string?)? Completion callback

---Load columns for this table asynchronously
---@param opts TableLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function TableClass:load_columns_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading columns...")
    local columns = self:load_columns()
    ctx.report_progress(100, "Columns loaded")
    return columns
  end, {
    name = opts.name or string.format("Loading columns for %s", self.table_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load indexes for this table asynchronously
---@param opts TableLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function TableClass:load_indexes_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading indexes...")
    local indexes = self:load_indexes()
    ctx.report_progress(100, "Indexes loaded")
    return indexes
  end, {
    name = opts.name or string.format("Loading indexes for %s", self.table_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load constraints for this table asynchronously
---@param opts TableLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function TableClass:load_constraints_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading constraints...")
    local constraints = self:load_constraints()
    ctx.report_progress(100, "Constraints loaded")
    return constraints
  end, {
    name = opts.name or string.format("Loading constraints for %s", self.table_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load table definition asynchronously
---@param opts TableLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function TableClass:load_definition_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading definition...")
    local definition = self:load_definition()
    ctx.report_progress(100, "Definition loaded")
    return definition
  end, {
    name = opts.name or string.format("Loading definition for %s", self.table_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

return TableClass
