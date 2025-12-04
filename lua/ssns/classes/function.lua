local BaseDbObject = require('ssns.classes.base')

---@class FunctionClass : BaseDbObject
---@field function_name string The function name
---@field schema_name string The schema name
---@field function_type string? Function type (e.g., "SCALAR_FUNCTION", "TABLE_VALUED_FUNCTION")
---@field parent SchemaClass The parent schema object
---@field parameters ParameterClass[]? Array of parameter objects
---@field parameters_loaded boolean Whether parameters have been loaded
---@field columns ColumnClass[]? Array of column objects (for table-valued functions)
---@field columns_loaded boolean Whether columns have been loaded
---@field definition string? The function definition SQL
---@field definition_loaded boolean Whether definition has been loaded
local FunctionClass = setmetatable({}, { __index = BaseDbObject })
FunctionClass.__index = FunctionClass

---Create a new Function instance
---@param opts {name: string, schema_name: string, function_type: string?, parent: SchemaClass}
---@return FunctionClass
function FunctionClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), FunctionClass)

  self.object_type = "function"
  self.function_name = opts.name
  self.schema_name = opts.schema_name
  self.function_type = opts.function_type
  self.parameters = nil
  self.parameters_loaded = false
  self.columns = nil
  self.columns_loaded = false
  self.definition = nil
  self.definition_loaded = false

  -- Set appropriate icon for function

  return self
end

---Get display name with schema prefix (e.g., [dbo].[FunctionName])
---@return string display_name
function FunctionClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.function_name)
  end
  return self.function_name
end

---Load function children (parameters and actions) - lazy loading
---@return boolean success
function FunctionClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes for UI
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI (SELECT, View Definition, etc.)
function FunctionClass:create_action_nodes()
  self:clear_children()

  -- Add SELECT action (functions are used in SELECT)
  local select_action = BaseDbObject.new({
    name = "SELECT",
    parent = self,
  })
  select_action.object_type = "action"
  select_action.action_type = "select"
  select_action.is_loaded = true
  table.insert(self.children, select_action)

  -- Add Parameters group (lazy loaded when expanded)
  local params_group = BaseDbObject.new({
    name = "Parameters",
    parent = self,
  })
  params_group.object_type = "parameter_group"

  -- Override load for parameters group
  params_group.load = function(group)
    if group.is_loaded then
      return true
    end
    self:load_parameters()
    group:clear_children()
    for _, param in ipairs(self.parameters) do
      -- Don't set parent - just add to children manually to avoid auto-add
      table.insert(group.children, param)
    end
    group.is_loaded = true
    return true
  end
  table.insert(self.children, params_group)

  -- Add Columns group for table-valued functions (lazy loaded when expanded)
  if self:is_table_valued() then
    local columns_group = BaseDbObject.new({
      name = "Columns",
      parent = self,
    })
    columns_group.object_type = "column_group"

    -- Override load for columns group
    columns_group.load = function(group)
      if group.is_loaded then
        return true
      end
      self:load_columns()
      group:clear_children()
      for _, col in ipairs(self.columns) do
        -- Don't set parent - just add to children manually to avoid auto-add
        table.insert(group.children, col)
      end
      group.is_loaded = true
      return true
    end
    table.insert(self.children, columns_group)
  end

  -- Add Function Definition action (ALTER shows definition)
  local definition_action = BaseDbObject.new({
    name = "ALTER",
    parent = self,
  })
  definition_action.object_type = "action"
  definition_action.action_type = "alter"
  definition_action.is_loaded = true
  table.insert(self.children, definition_action)

  -- Add DROP action
  local drop_action = BaseDbObject.new({
    name = "DROP",
    parent = self,
  })
  drop_action.object_type = "action"
  drop_action.action_type = "drop"
  drop_action.is_loaded = true
  table.insert(self.children, drop_action)

  -- Add DEPENDENCIES action
  local dependencies_action = BaseDbObject.new({
    name = "DEPENDENCIES",
    parent = self,
  })
  dependencies_action.object_type = "action"
  dependencies_action.action_type = "dependencies"
  dependencies_action.is_loaded = true
  table.insert(self.children, dependencies_action)
end

---Load parameters for this function (lazy loading)
---@return ParameterClass[]
function FunctionClass:load_parameters()
  if self.parameters_loaded then
    return self.parameters
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Get parameters query from adapter
  local query = adapter:get_parameters_query(db.db_name, self.schema_name, self.function_name, "FUNCTION")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Parse results
  local parameters = adapter:parse_parameters(results)

  -- Create parameter objects (don't set parent to avoid adding to function's children)
  self.parameters = {}
  for _, param_data in ipairs(parameters) do
    local ParameterClass = require('ssns.classes.parameter')
    local param_obj = ParameterClass.new({
      name = param_data.name,
      data_type = param_data.data_type,
      mode = param_data.mode,
      has_default = param_data.has_default,
      max_length = param_data.max_length,
      precision = param_data.precision,
      scale = param_data.scale,
      parent = nil,
    })
    table.insert(self.parameters, param_obj)
  end

  self.parameters_loaded = true
  return self.parameters
end

---Get parameters (load if not already loaded)
---@return ParameterClass[]
function FunctionClass:get_parameters()
  if not self.parameters_loaded then
    self:load_parameters()
  end
  return self.parameters
end

---Load columns for this table-valued function (lazy loading)
---@return ColumnClass[]
function FunctionClass:load_columns()
  if self.columns_loaded then
    return self.columns
  end

  -- Only table-valued functions have columns
  if not self:is_table_valued() then
    self.columns = {}
    self.columns_loaded = true
    return self.columns
  end

  local adapter = self:get_adapter()

  -- Get database using get_database() method (handles both schema and non-schema databases)
  local db = self:get_database()

  -- Validate we have a database
  if not db then
    vim.notify(string.format("SSNS: Function %s has no parent database", self.function_name), vim.log.levels.ERROR)
    self.columns = {}
    self.columns_loaded = true
    return self.columns
  end

  if not db.db_name then
    vim.notify(string.format("SSNS: Function %s parent '%s' is not a database (type: %s)",
      self.function_name,
      db.name or "unknown",
      db.object_type or "unknown"), vim.log.levels.ERROR)
    self.columns = {}
    self.columns_loaded = true
    return self.columns
  end

  -- Get TVF columns query from adapter (if available)
  local query
  if adapter.get_tvf_columns_query then
    query = adapter:get_tvf_columns_query(db.db_name, self.schema_name, self.function_name)
  else
    -- Fallback: use standard columns query (may not work for all databases)
    query = adapter:get_columns_query(db.db_name, self.schema_name, self.function_name)
  end

  -- Execute query
  local results = adapter:execute(self:get_server().connection_config, query)

  -- Check for errors
  if results.error then
    vim.notify(string.format("SSNS: Error loading columns: %s", results.error.message or vim.inspect(results.error)), vim.log.levels.ERROR)
  end

  -- Parse results (same format as table columns)
  local columns = adapter:parse_columns(results)

  -- Create column objects (don't set parent to avoid adding to function's children)
  self.columns = {}
  for _, col_data in ipairs(columns) do
    local col_obj = adapter:create_column(nil, col_data)
    table.insert(self.columns, col_obj)
  end

  self.columns_loaded = true
  return self.columns
end

---Get columns (load if not already loaded)
---@return ColumnClass[]
function FunctionClass:get_columns()
  if not self.columns_loaded then
    self:load_columns()
  end
  return self.columns
end

---Load the function definition SQL
---@return string? definition
function FunctionClass:load_definition()
  if self.definition_loaded then
    return self.definition
  end

  local adapter = self:get_adapter()

  -- Navigate to database based on server type:
  -- Schema-based (SQL Server, PostgreSQL): Function -> Schema -> Database
  -- Non-schema (MySQL, SQLite): Function -> Database
  local db
  if adapter.features.schemas then
    db = self.parent.parent  -- Function -> Schema -> Database
  else
    db = self.parent  -- Function -> Database
  end

  -- Get definition query from adapter
  local query = adapter:get_definition_query(db.db_name, self.schema_name, self.function_name, "FUNCTION")

  -- Execute query
  local results = adapter:execute(self:get_server().connection_config, query, { use_delimiter = false })

  -- Use adapter's parse method for consistent result handling
  self.definition = adapter:parse_definition(results)

  self.definition_loaded = true
  return self.definition
end

---Get the function definition (load if not already loaded)
---@return string?
function FunctionClass:get_definition()
  if not self.definition_loaded then
    self:load_definition()
  end
  return self.definition
end

---Check if this is a table-valued function
---@return boolean
function FunctionClass:is_table_valued()
  if not self.function_type then
    return false
  end

  return self.function_type:match("TABLE") ~= nil
    or self.function_type == "IF"  -- SQL Server inline table-valued
    or self.function_type == "TF"  -- SQL Server multi-statement table-valued
end

---Generate a SELECT statement for this function
---@return string sql
function FunctionClass:generate_select()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.function_name
  )

  local parameters = self:get_parameters()

  -- Build parameter list with placeholders
  local param_parts = {}
  for _, param in ipairs(parameters) do
    table.insert(param_parts, "?")
  end

  local param_list = #param_parts > 0 and table.concat(param_parts, ", ") or ""

  if self:is_table_valued() then
    -- Table-valued function - use FROM
    return string.format("SELECT * FROM %s(%s);", qualified_name, param_list)
  else
    -- Scalar function - use SELECT
    return string.format("SELECT %s(%s);", qualified_name, param_list)
  end
end

---Generate a DROP statement for this function
---@return string sql
function FunctionClass:generate_drop()
  local adapter = self:get_adapter()
  -- Don't include database name - use the connection context
  local qualified_name = adapter:get_qualified_name(
    nil,  -- database_name (use connection context)
    self.schema_name,
    self.function_name
  )

  return string.format("DROP FUNCTION %s;", qualified_name)
end

---Get the full qualified name for this function
---@return string
function FunctionClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.function_name
  )
end

---Get string representation for debugging
---@return string
function FunctionClass:to_string()
  return string.format(
    "FunctionClass{name=%s, schema=%s, type=%s, parameters=%d}",
    self.name,
    self.schema_name,
    self.function_type or "unknown",
    self.parameters and #self.parameters or 0
  )
end

---Get metadata info for display in floating window
---@return table metadata Standardized metadata structure with sections
function FunctionClass:get_metadata_info()
  local sections = {}

  -- Parameters section
  local parameters = self:get_parameters()
  local param_rows = {}

  for _, param in ipairs(parameters or {}) do
    local name = param.parameter_name or param.name or ""
    local full_type = param.get_full_type and param:get_full_type() or param.data_type or ""
    local mode = param.mode or param.direction or "IN"
    local has_default = param.has_default
    local default_val = "-"
    if param.default_value and param.default_value ~= "" then
      default_val = param.default_value
    elseif has_default then
      default_val = "(has default)"
    end

    table.insert(param_rows, {name, full_type, mode, default_val})
  end

  table.insert(sections, {
    title = "PARAMETERS",
    headers = {"Name", "Type", "Mode", "Default"},
    rows = param_rows,
  })

  -- For table-valued functions, add return columns section
  if self:is_table_valued() then
    local columns = self:get_columns()
    local col_rows = {}

    for _, col in ipairs(columns or {}) do
      local name = col.column_name or col.name or ""
      local full_type = col.get_full_type and col:get_full_type() or col.data_type or ""
      local nullable = "YES"
      if col.is_nullable == false or col.nullable == false then
        nullable = "NO"
      end

      table.insert(col_rows, {name, full_type, nullable})
    end

    table.insert(sections, {
      title = "RETURN COLUMNS (Table-Valued)",
      headers = {"Name", "Type", "Nullable"},
      rows = col_rows,
    })
  end

  return {
    sections = sections,
  }
end

return FunctionClass
