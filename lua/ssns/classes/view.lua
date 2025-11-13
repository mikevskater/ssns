local BaseDbObject = require('ssns.classes.base')

---@class ViewClass : BaseDbObject
---@field view_name string The view name
---@field schema_name string The schema name
---@field parent SchemaClass The parent schema object
---@field columns ColumnClass[]? Array of column objects
---@field columns_loaded boolean Whether columns have been loaded
---@field definition string? The view definition SQL
---@field definition_loaded boolean Whether definition has been loaded
local ViewClass = setmetatable({}, { __index = BaseDbObject })
ViewClass.__index = ViewClass

---Create a new View instance
---@param opts {name: string, schema_name: string, parent: SchemaClass}
---@return ViewClass
function ViewClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), ViewClass)

  self.object_type = "view"
  self.view_name = opts.name
  self.schema_name = opts.schema_name
  self.columns = nil
  self.columns_loaded = false
  self.definition = nil
  self.definition_loaded = false

  -- Set appropriate icon for view
  self.ui_state.icon = ""  -- View icon

  return self
end

---Get display name with schema prefix (e.g., [dbo].[ViewName])
---@return string display_name
function ViewClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.view_name)
  end
  return self.view_name
end

---Load view children (columns and actions) - lazy loading
---@return boolean success
function ViewClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes and detail groups for UI
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI (SELECT, View Definition, etc.)
function ViewClass:create_action_nodes()
  self:clear_children()

  -- Add SELECT action
  local select_action = BaseDbObject.new({
    name = "SELECT",
    parent = self,
  })
  select_action.ui_state.icon = ""
  select_action.object_type = "action"
  select_action.action_type = "select"
  select_action.is_loaded = true

  -- Add Columns group (lazy loaded when expanded)
  local columns_group = BaseDbObject.new({
    name = "Columns",
    parent = self,
  })
  columns_group.ui_state.icon = ""
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

  -- Add View Definition action (ALTER shows definition)
  local definition_action = BaseDbObject.new({
    name = "ALTER",
    parent = self,
  })
  definition_action.ui_state.icon = ""
  definition_action.object_type = "action"
  definition_action.action_type = "alter"
  definition_action.is_loaded = true

  -- Add DROP action
  local drop_action = BaseDbObject.new({
    name = "DROP",
    parent = self,
  })
  drop_action.ui_state.icon = ""
  drop_action.object_type = "action"
  drop_action.action_type = "drop"
  drop_action.is_loaded = true

  -- Add DEPENDENCIES action
  local dependencies_action = BaseDbObject.new({
    name = "DEPENDENCIES",
    parent = self,
  })
  dependencies_action.ui_state.icon = ""
  dependencies_action.object_type = "action"
  dependencies_action.action_type = "dependencies"
  dependencies_action.is_loaded = true
end

---Load columns for this view (lazy loading)
---@return ColumnClass[]
function ViewClass:load_columns()
  if self.columns_loaded then
    return self.columns
  end

  local adapter = self:get_adapter()

  -- Navigate up: View -> Database (no schemas in new structure)
  local db = self.parent

  -- Views use the same columns query as tables
  local query = adapter:get_columns_query(db.db_name, self.schema_name, self.view_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Parse results
  local columns = adapter:parse_columns(results)

  -- Create column objects (don't set parent to avoid adding to view's children)
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
function ViewClass:get_columns()
  if not self.columns_loaded then
    self:load_columns()
  end
  return self.columns
end

---Find a column by name
---@param column_name string
---@return ColumnClass?
function ViewClass:find_column(column_name)
  local columns = self:get_columns()

  for _, col in ipairs(columns) do
    if col.name == column_name then
      return col
    end
  end

  return nil
end

---Load the view definition SQL
---@return string? definition
function ViewClass:load_definition()
  if self.definition_loaded then
    return self.definition
  end

  local adapter = self:get_adapter()

  -- Navigate up: View -> Database (no schemas in new structure)
  local db = self.parent

  -- Get definition query from adapter
  local query = adapter:get_definition_query(db.db_name, self.schema_name, self.view_name, "VIEW")

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(self:get_server().connection, query)

  -- Extract definition from results
  if results and #results > 0 then
    self.definition = results[1].definition or results[1][1]
  end

  self.definition_loaded = true
  return self.definition
end

---Get the view definition (load if not already loaded)
---@return string?
function ViewClass:get_definition()
  if not self.definition_loaded then
    self:load_definition()
  end
  return self.definition
end

---Generate a SELECT statement for this view
---@param top number? Optional TOP/LIMIT clause
---@return string sql
function ViewClass:generate_select(top)
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.view_name
  )

  if top then
    if adapter.db_type == "sqlserver" then
      return string.format("SELECT TOP %d * FROM %s;", top, qualified_name)
    elseif adapter.db_type == "postgres" or adapter.db_type == "mysql" then
      return string.format("SELECT * FROM %s LIMIT %d;", qualified_name, top)
    end
  end

  return string.format("SELECT * FROM %s;", qualified_name)
end

---Generate a DROP statement for this view
---@return string sql
function ViewClass:generate_drop()
  local adapter = self:get_adapter()
  local qualified_name = adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.view_name
  )

  return string.format("DROP VIEW %s;", qualified_name)
end

---Get the full qualified name for this view
---@return string
function ViewClass:get_qualified_name()
  local adapter = self:get_adapter()
  return adapter:get_qualified_name(
    self.parent.parent.db_name,
    self.schema_name,
    self.view_name
  )
end

---Get string representation for debugging
---@return string
function ViewClass:to_string()
  return string.format(
    "ViewClass{name=%s, schema=%s, columns=%d}",
    self.name,
    self.schema_name,
    self.columns and #self.columns or 0
  )
end

return ViewClass
