---@class UiTree
---Tree rendering and interaction for SSNS
local UiTree = {}

---Line to object mapping (line_number -> object)
---@type table<number, BaseDbObject>
UiTree.line_map = {}

---Object to line mapping (object -> line_number)
---@type table<BaseDbObject, number>
UiTree.object_map = {}

---Get icon for object type
---@param object_type string
---@param icons table
---@return string
function UiTree.get_object_icon(object_type, icons)
  -- Map object types to icon names
  local icon_map = {
    database = icons.database or "",
    schema = icons.schema or "",
    table = icons.table or "",
    view = icons.view or "",
    procedure = icons.procedure or "",
    ["function"] = icons["function"] or "",
    column = icons.column or "",
    index = icons.index or "",
    key = icons.key or "",
    parameter = icons.parameter or "",
    sequence = icons.sequence or "",
    synonym = icons.synonym or "",
    action = icons.action or "",
    -- Groups use folder icon
    databases_group = icons.schema or "",
    tables_group = icons.schema or "",
    views_group = icons.schema or "",
    procedures_group = icons.schema or "",
    functions_group = icons.schema or "",
    sequences_group = icons.schema or "",
    synonyms_group = icons.schema or "",
    column_group = icons.schema or "",
    index_group = icons.schema or "",
    key_group = icons.schema or "",
    parameter_group = icons.schema or "",
    actions_group = icons.schema or "",
  }

  return icon_map[object_type] or ""
end

---Render the entire tree
function UiTree.render()
  local Cache = require('ssns').get_cache()
  local Buffer = require('ssns.ui.buffer')

  -- Clear mappings
  UiTree.line_map = {}
  UiTree.object_map = {}

  -- Build lines
  local lines = {}
  local line_number = 1

  -- Get all servers
  local servers = Cache.get_all_servers()

  if #servers == 0 then
    table.insert(lines, "No servers configured")
    table.insert(lines, "")
    table.insert(lines, "Add servers in your setup():")
    table.insert(lines, "  connections = {")
    table.insert(lines, '    my_server = "sqlserver://.\\\\SQLEXPRESS/master"')
    table.insert(lines, "  }")
  else
    -- Render each server
    for _, server in ipairs(servers) do
      UiTree.render_server(server, lines, line_number, 0)
      line_number = #lines + 1
    end
  end

  -- Write to buffer
  Buffer.set_lines(lines)

  -- Apply syntax highlighting
  local Highlights = require('ssns.ui.highlights')
  Highlights.apply(UiTree.line_map)
end

---Render a server and its children
---@param server ServerClass
---@param lines string[]
---@param line_number number
---@param indent_level number
function UiTree.render_server(server, lines, line_number, indent_level)
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = server.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")

  -- Get database-type specific server icon
  local server_icon = icons.server or ""
  local db_type = server:get_db_type()
  if db_type == "sqlserver" then
    server_icon = icons.server_sqlserver or icons.server or ""
  elseif db_type == "postgres" or db_type == "postgresql" then
    server_icon = icons.server_postgres or icons.server or ""
  elseif db_type == "mysql" then
    server_icon = icons.server_mysql or icons.server or ""
  elseif db_type == "sqlite" then
    server_icon = icons.server_sqlite or icons.server or ""
  elseif db_type == "bigquery" then
    server_icon = icons.server_bigquery or icons.server or ""
  end

  local status = server:get_status_icon()

  -- Server line with icon
  local line = string.format("%s%s %s %s %s", indent, expand_icon, server_icon, server.name, status)
  table.insert(lines, line)

  -- Map line to object
  local line_num = #lines
  UiTree.line_map[line_num] = server
  UiTree.object_map[server] = line_num

  -- If expanded, render children (Databases group, etc.)
  if server.ui_state.expanded then
    if server.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      table.insert(lines, indent .. "    " .. error_icon .. " Error: " .. server.ui_state.error)
    elseif server.ui_state.loading then
      -- Show loading indicator
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    elseif server.is_loaded and server:has_children() then
      -- Render server children (Databases group, New Query, Saved Queries)
      for _, child in ipairs(server.children) do
        if child.object_type == "databases_group" then
          -- Render databases group
          UiTree.render_object(child, lines, indent_level + 1)
        else
          -- Render other server-level items (New Query, Saved Queries - Phase 6)
          UiTree.render_object(child, lines, indent_level + 1)
        end
      end
    elseif server:is_connected() and not server.is_loaded then
      -- Show loading indicator (fallback if loading flag not set)
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    end
  end
end

---Render a database and its children
---@param db DbClass
---@param lines string[]
---@param indent_level number
function UiTree.render_database(db, lines, indent_level)
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = db.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  local db_icon = icons.database or ""
  local status = db:get_status_icon()

  -- Database line with icon
  local line = string.format("%s%s %s %s %s", indent, expand_icon, db_icon, db.name, status)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = db
  UiTree.object_map[db] = #lines

  -- If expanded, render object type groups (TABLES, VIEWS, etc.)
  if db.ui_state.expanded then
    if db.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      table.insert(lines, indent .. "    " .. error_icon .. " Error: " .. db.ui_state.error)
    elseif db.ui_state.loading then
      -- Show loading indicator
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    elseif db.is_loaded and db:has_children() then
      -- Render each object type group
      for _, group in ipairs(db.children) do
        UiTree.render_object(group, lines, indent_level + 1)
      end
    else
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    end
  end
end

---Render a schema and its children
---@param schema SchemaClass
---@param lines string[]
---@param indent_level number
function UiTree.render_schema(schema, lines, indent_level)
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = schema.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  local schema_icon = icons.schema or ""

  -- Schema line with icon
  local line = string.format("%s%s %s %s", indent, expand_icon, schema_icon, schema.name)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = schema
  UiTree.object_map[schema] = #lines

  -- If expanded, render object groups
  if schema.ui_state.expanded then
    if schema.is_loaded and schema:has_children() then
      for _, group in ipairs(schema:get_children()) do
        UiTree.render_object_group(group, lines, indent_level + 1)
      end
    else
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    end
  end
end

---Render an object group (TABLES, VIEWS, etc.)
---@param group BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_object_group(group, lines, indent_level)
  local indent = string.rep("  ", indent_level)
  local icon = group.ui_state.expanded and "▾ " or "▸ "

  -- Group line
  local line = string.format("%s%s%s", indent, icon, group.name)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = group
  UiTree.object_map[group] = #lines

  -- If expanded, render children
  if group.ui_state.expanded and group:has_children() then
    for _, child in ipairs(group:get_children()) do
      UiTree.render_object(child, lines, indent_level + 1)
    end
  end
end

---Render a database object (table, view, etc.)
---@param obj BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_object(obj, lines, indent_level)
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons
  local indent = string.rep("  ", indent_level)

  -- Check if this is an action or detail node
  if obj.object_type == "action" then
    -- Action nodes (SELECT, DROP, etc.)
    local action_icon = icons.action or ""
    local line = string.format("%s  %s %s", indent, action_icon, obj.name)
    table.insert(lines, line)
    UiTree.line_map[#lines] = obj
    UiTree.object_map[obj] = #lines
    return
  end

  -- Regular objects with potential children
  -- Tables, views, procedures, functions always have children (action groups)
  -- Groups are expandable
  -- Or if already loaded and has children
  local has_children = obj:has_children()
    or obj.object_type == "database"
    or obj.object_type == "table"
    or obj.object_type == "view"
    or obj.object_type == "procedure"
    or obj.object_type == "function"
    or obj.object_type == "synonym"
    or obj.object_type == "databases_group"
    or obj.object_type == "tables_group"
    or obj.object_type == "views_group"
    or obj.object_type == "procedures_group"
    or obj.object_type == "functions_group"
    or obj.object_type == "synonyms_group"
    or obj.object_type == "column_group"
    or obj.object_type == "index_group"
    or obj.object_type == "key_group"
    or obj.object_type == "parameter_group"
    or obj.object_type == "actions_group"

  local expand_icon = ""
  if has_children then
    expand_icon = obj.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  end

  -- Get object-type specific icon
  local obj_icon = UiTree.get_object_icon(obj.object_type, icons)

  -- Object line with icon
  local display_name = obj.get_display_name and obj:get_display_name() or obj.name
  local line = string.format("%s%s %s %s", indent, expand_icon, obj_icon, display_name)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = obj
  UiTree.object_map[obj] = #lines

  -- If expanded, render children
  if obj.ui_state.expanded then
    if obj.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      table.insert(lines, indent .. "  " .. error_icon .. " Error: " .. obj.ui_state.error)
    elseif obj.ui_state.loading then
      -- Show loading indicator
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "  " .. loading_icon .. " Loading...")
    else
      -- Check if this is a structural group that needs alignment
      if obj.object_type == "column_group" or obj.object_type == "index_group" or
         obj.object_type == "key_group" or obj.object_type == "parameter_group" then
        -- Load the group if not loaded (this populates children)
        if not obj.is_loaded and obj.load then
          obj:load()
        end
        UiTree.render_aligned_group(obj, lines, indent_level + 1)
      elseif obj:has_children() then
        -- Regular children rendering (only if has children)
        for _, child in ipairs(obj:get_children()) do
          UiTree.render_object(child, lines, indent_level + 1)
        end
      end
    end
  end
end

---Render a structural group with aligned columns
---@param group BaseDbObject
---@param lines string[]
---@param indent_level number
function UiTree.render_aligned_group(group, lines, indent_level)
  local indent = string.rep("  ", indent_level)
  local children = group:get_children()

  if #children == 0 then
    -- Show "(No <type>)" message for empty groups
    -- Keep plural form (Columns, Indexes, Keys, Parameters)
    local message = string.format("(No %s)", group.name)
    local line = indent .. "  " .. message
    table.insert(lines, line)
    -- Don't map to any object for empty message
    return
  end

  -- First pass: Calculate max widths for each field
  local max_widths = {}
  local formatted_rows = {}

  for _, child in ipairs(children) do
    local row = UiTree.format_detail_row(child, group.object_type)
    if row then
      table.insert(formatted_rows, row)

      -- Update max widths
      for idx, value in ipairs(row) do
        if not max_widths[idx] then
          max_widths[idx] = 0
        end
        if #value > max_widths[idx] then
          max_widths[idx] = #value
        end
      end
    end
  end

  -- Get config for icons
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  -- Second pass: Render with aligned columns
  for i, row in ipairs(formatted_rows) do
    local parts = {}
    for idx, value in ipairs(row) do
      local width = max_widths[idx] or #value
      local padded = value .. string.rep(" ", width - #value)
      table.insert(parts, padded)
    end

    -- Get icon for this object type
    local child = children[i]
    local obj_icon = UiTree.get_object_icon(child.object_type, icons)

    -- Add icon and aligned content
    local line = indent .. "  " .. obj_icon .. " " .. table.concat(parts, " | ")
    table.insert(lines, line)

    -- Map line to the original child object
    UiTree.line_map[#lines] = child
    UiTree.object_map[child] = #lines
  end
end

---Format a detail row for alignment
---@param obj BaseDbObject
---@param group_type string
---@return string[]?
function UiTree.format_detail_row(obj, group_type)
  if group_type == "column_group" then
    -- Format: ColumnName | DataType | Nullable
    local parts = {}
    table.insert(parts, obj.column_name or obj.name)

    -- Get full type with length/precision
    local data_type = obj.get_full_type and obj:get_full_type() or (obj.data_type or "")
    table.insert(parts, data_type)

    table.insert(parts, obj.nullable and "NULL" or "NOT NULL")

    return parts

  elseif group_type == "index_group" then
    -- Format: IndexName | Type | Columns
    local parts = {}
    table.insert(parts, obj.index_name or obj.name)

    local index_type = ""
    if obj.is_primary then
      index_type = "PRIMARY KEY"
    elseif obj.is_unique then
      index_type = "UNIQUE"
    else
      index_type = obj.index_type or "INDEX"
    end
    table.insert(parts, index_type)

    -- Columns (if available)
    if obj.columns and #obj.columns > 0 then
      table.insert(parts, "(" .. table.concat(obj.columns, ", ") .. ")")
    else
      table.insert(parts, "()")
    end

    return parts

  elseif group_type == "key_group" then
    -- Format: ConstraintName | Type | Columns
    local parts = {}
    table.insert(parts, obj.constraint_name or obj.name)
    table.insert(parts, obj.constraint_type or "CONSTRAINT")

    if obj.columns and #obj.columns > 0 then
      table.insert(parts, "(" .. table.concat(obj.columns, ", ") .. ")")
    else
      table.insert(parts, "()")
    end

    return parts

  elseif group_type == "parameter_group" then
    -- Format: ParameterName | DataType | Mode
    local parts = {}
    local param_name = obj.parameter_name or obj.name or ""
    table.insert(parts, param_name)

    -- Get full type with length/precision
    local data_type = obj.get_full_type and obj:get_full_type() or (obj.data_type or "")
    table.insert(parts, data_type)

    -- Check if this is a return value
    if param_name == "RETURNS" then
      table.insert(parts, "RETURN")
    else
      table.insert(parts, obj.mode or "IN")
    end

    return parts
  end

  return nil
end

---Toggle node expansion at current cursor
function UiTree.toggle_node()
  local Buffer = require('ssns.ui.buffer')
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Handle action nodes
  if obj.object_type == "action" then
    UiTree.execute_action(obj)
    return
  end

  -- Handle object reference nodes (from SCHEMAS group)
  if obj.object_type == "object_reference" and obj.referenced_object then
    -- Navigate to the actual object in the main tree
    UiTree.navigate_to_object(obj.referenced_object)
    return
  end

  -- Check if we're expanding or collapsing
  local was_expanded = obj.ui_state.expanded

  -- Toggle expansion
  obj:toggle_expand()

  -- If expanding and not loaded, load asynchronously
  if obj.ui_state.expanded and not obj.is_loaded and obj.load then
    UiTree.load_node_async(obj, line_number)
  else
    -- Re-render tree immediately
    UiTree.render()

    -- Check if smart cursor positioning is enabled
    local Config = require('ssns.config')
    local smart_positioning = Config.get_ui().smart_cursor_positioning

    -- Position cursor appropriately
    if obj.ui_state.expanded and not was_expanded then
      -- Just expanded - move to first child if exists
      if obj:has_children() or obj.ui_state.loading or obj.ui_state.error then
        local child_line = line_number + 1
        local col = smart_positioning and Buffer.get_name_column(child_line) or 0
        Buffer.set_cursor(child_line, col)
        -- Update indent tracking
        if smart_positioning then
          Buffer.last_indent_info = {
            line = child_line,
            indent_level = Buffer.get_indent_level(child_line),
            column = col,
          }
        end
      else
        -- No children, stay on current line
        local col = smart_positioning and Buffer.get_name_column(line_number) or 0
        Buffer.set_cursor(line_number, col)
        -- Update indent tracking
        if smart_positioning then
          Buffer.last_indent_info = {
            line = line_number,
            indent_level = Buffer.get_indent_level(line_number),
            column = col,
          }
        end
      end
    else
      -- Collapsed or stayed same - restore cursor position
      local col = smart_positioning and Buffer.get_name_column(line_number) or 0
      Buffer.set_cursor(line_number, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = line_number,
          indent_level = Buffer.get_indent_level(line_number),
          column = col,
        }
      end
    end
  end
end

---Load a node asynchronously
---@param obj BaseDbObject
---@param line_number number
function UiTree.load_node_async(obj, line_number)
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  -- Set loading state
  obj.ui_state.loading = true
  obj.ui_state.error = nil

  -- Render with loading indicator
  UiTree.render()
  local col = smart_positioning and Buffer.get_name_column(line_number) or 0
  Buffer.set_cursor(line_number, col)

  -- Load asynchronously using vim.schedule
  vim.schedule(function()
    local success, result = pcall(function()
      return obj:load()
    end)

    -- Clear loading state
    obj.ui_state.loading = false

    -- Check if pcall failed (threw error)
    if not success then
      obj.ui_state.error = tostring(result)
      vim.notify(string.format("SSNS: Failed to load %s: %s", obj.name, result), vim.log.levels.ERROR)
    -- Check if load() returned false (failed without throwing)
    elseif result == false then
      local error_msg = obj.error_message or "Unknown error"
      obj.ui_state.error = error_msg
      vim.notify(string.format("SSNS: Failed to load %s: %s", obj.name, error_msg), vim.log.levels.ERROR)
    end

    -- Update success flag based on both checks
    success = success and result ~= false

    -- Re-render tree with results or error
    UiTree.render()

    -- Position cursor at first child if loaded successfully
    if success and obj:has_children() then
      local child_line = line_number + 1
      local child_col = smart_positioning and Buffer.get_name_column(child_line) or 0
      Buffer.set_cursor(child_line, child_col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = child_line,
          indent_level = Buffer.get_indent_level(child_line),
          column = child_col,
        }
      end
    else
      -- Error or no children, stay on current line
      local col = smart_positioning and Buffer.get_name_column(line_number) or 0
      Buffer.set_cursor(line_number, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = line_number,
          indent_level = Buffer.get_indent_level(line_number),
          column = col,
        }
      end
    end
  end)
end

---Execute an action node
---@param action BaseDbObject
function UiTree.execute_action(action)
  local Query = require('ssns.ui.query')
  local parent = action.parent

  -- Navigate up past groups to find actual parent object
  while parent and (parent.object_type == "column_group" or parent.object_type == "index_group" or parent.object_type == "key_group" or parent.object_type == "actions_group") do
    parent = parent.parent
  end

  if not parent then
    vim.notify("SSNS: Cannot find parent object for action", vim.log.levels.WARN)
    return
  end

  -- Get the server and database for this action
  local server = parent:get_server()
  local database = parent:get_database()

  if action.action_type == "select" then
    -- Generate SELECT statement
    if parent.generate_select then
      local sql = parent:generate_select(100)
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "drop" then
    -- Generate DROP statement (with confirmation)
    if parent.generate_drop then
      local sql = parent:generate_drop()
      local confirm = vim.fn.confirm(
        string.format("Generate DROP statement for %s?", parent.name),
        "&Yes\n&No",
        2
      )
      if confirm == 1 then
        Query.create_query_buffer(server, database, sql, parent.name)
      end
    end
  elseif action.action_type == "exec" then
    -- Generate EXEC statement
    if parent.generate_exec then
      local sql = parent:generate_exec()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "alter" then
    -- Show definition (ALTER displays the object definition)
    if parent.get_definition then
      local definition = parent:get_definition()
      if definition then
        Query.create_query_buffer(server, database, definition, parent.name)
      else
        vim.notify("No definition available", vim.log.levels.WARN)
      end
    end
  elseif action.action_type == "dependencies" then
    -- Show dependencies
    UiTree.show_dependencies(parent)
  elseif action.action_type == "count" then
    -- Generate COUNT query
    if parent.generate_count then
      local sql = parent:generate_count()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "describe" then
    -- Generate DESCRIBE query (sp_help for SQL Server)
    if parent.generate_describe then
      local sql = parent:generate_describe()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "insert" then
    -- Generate INSERT template
    if parent.generate_insert then
      local sql = parent:generate_insert()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "update" then
    -- Generate UPDATE template
    if parent.generate_update then
      local sql = parent:generate_update()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "delete" then
    -- Generate DELETE template
    if parent.generate_delete then
      local sql = parent:generate_delete()
      Query.create_query_buffer(server, database, sql, parent.name)
    end
  elseif action.action_type == "goto" then
    -- Navigate to base object in tree (for synonyms)
    if parent.resolve then
      local base_object, error_msg = parent:resolve()
      if base_object then
        UiTree.navigate_to_object(base_object)
      else
        vim.notify(string.format("Cannot navigate: %s", error_msg or "Unknown error"), vim.log.levels.WARN)
      end
    end
  end
end

---Show object dependencies in a floating window
---@param obj BaseDbObject
function UiTree.show_dependencies(obj)
  local adapter = obj:get_adapter()
  local server = obj:get_server()

  -- Get database and schema/object names based on object type
  local database, schema_name, object_name

  if obj.object_type == "table" or obj.object_type == "view" then
    database = obj.parent  -- Table/View -> Database
    schema_name = obj.schema_name
    object_name = obj.table_name or obj.view_name
  elseif obj.object_type == "synonym" then
    database = obj.parent  -- Synonym -> Database
    schema_name = obj.schema_name
    object_name = obj.synonym_name
  elseif obj.object_type == "procedure" then
    database = obj.parent  -- Procedure -> Database
    schema_name = obj.schema_name
    object_name = obj.procedure_name
  elseif obj.object_type == "function" then
    database = obj.parent  -- Function -> Database
    schema_name = obj.schema_name
    object_name = obj.function_name
  else
    vim.notify("SSNS: Dependencies not supported for this object type", vim.log.levels.WARN)
    return
  end

  -- Get dependencies query
  local query = adapter:get_dependencies_query(database.db_name, schema_name, object_name)

  -- Execute query
  local results, err = adapter:execute(server.connection, query)

  if err then
    vim.notify(string.format("SSNS: Failed to fetch dependencies: %s", err), vim.log.levels.ERROR)
    return
  end

  -- Parse dependencies
  local dependencies = adapter:parse_dependencies(results)

  if #dependencies == 0 then
    vim.notify("SSNS: No dependencies found", vim.log.levels.INFO)
    return
  end

  -- Format dependencies for display
  local lines = {
    string.format("=== Dependencies for %s ===", obj.name),
    "",
  }

  -- Group by dependency type
  local depends_on = {}
  local depended_on_by = {}

  for _, dep in ipairs(dependencies) do
    if dep.dependency_type == "DEPENDS ON" then
      table.insert(depends_on, dep)
    else
      table.insert(depended_on_by, dep)
    end
  end

  -- Show "DEPENDS ON" section
  if #depends_on > 0 then
    table.insert(lines, "This object depends on:")
    table.insert(lines, "")
    for _, dep in ipairs(depends_on) do
      table.insert(lines, string.format("  [%s].[%s] (%s)", dep.schema_name, dep.object_name, dep.object_type))
    end
    table.insert(lines, "")
  end

  -- Show "DEPENDED ON BY" section
  if #depended_on_by > 0 then
    table.insert(lines, "This object is depended on by:")
    table.insert(lines, "")
    for _, dep in ipairs(depended_on_by) do
      table.insert(lines, string.format("  [%s].[%s] (%s)", dep.schema_name, dep.object_name, dep.object_type))
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.format("Total: %d dependencies", #dependencies))

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'ssns-dependencies')

  -- Calculate window size
  local width = 80
  local height = math.min(#lines + 2, 30)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Dependencies ",
    title_pos = "center",
  })

  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { noremap = true, silent = true })
end

---Refresh node at current cursor
function UiTree.refresh_node()
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Reload the object asynchronously
  if obj.reload then
    -- Set loading state
    obj.ui_state.loading = true
    obj.ui_state.error = nil

    -- Render with loading indicator
    UiTree.render()
    local col = smart_positioning and Buffer.get_name_column(line_number) or 0
    Buffer.set_cursor(line_number, col)

    -- Reload asynchronously
    vim.schedule(function()
      local success, err = pcall(function()
        obj:reload()
      end)

      -- Clear loading state
      obj.ui_state.loading = false

      if success then
        vim.notify(string.format("SSNS: Refreshed %s", obj.name), vim.log.levels.INFO)
      else
        -- Set error state
        obj.ui_state.error = tostring(err)
        vim.notify(string.format("SSNS: Failed to refresh %s: %s", obj.name, err), vim.log.levels.ERROR)
      end

      -- Re-render tree with results or error
      UiTree.render()
      local col = smart_positioning and Buffer.get_name_column(line_number) or 0
      Buffer.set_cursor(line_number, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = line_number,
          indent_level = Buffer.get_indent_level(line_number),
          column = col,
        }
      end
    end)
  end
end

---Refresh all servers
function UiTree.refresh_all()
  local Cache = require('ssns').get_cache()
  Cache.refresh_all()
  vim.notify("Refreshed all servers", vim.log.levels.INFO)

  -- Re-render tree
  UiTree.render()
end

---Toggle connection for server/database at current cursor
function UiTree.toggle_connection()
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Check if it's a server or database
  if obj.toggle_connection then
    obj:toggle_connection()

    -- Re-render tree
    UiTree.render()

    -- Restore cursor position with smart column
    local col = smart_positioning and Buffer.get_name_column(line_number) or 0
    Buffer.set_cursor(line_number, col)
    -- Update indent tracking
    if smart_positioning then
      Buffer.last_indent_info = {
        line = line_number,
        indent_level = Buffer.get_indent_level(line_number),
        column = col,
      }
    end
  else
    vim.notify("Can only toggle connection on servers/databases", vim.log.levels.WARN)
  end
end

---Set lualine color for current server or database
function UiTree.set_lualine_color()
  local Buffer = require('ssns.ui.buffer')
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Determine if it's a server or database
  local is_server = obj.object_type == "server"
  local is_database = obj.object_type == "database"

  if not is_server and not is_database then
    vim.notify("SSNS: Can only set lualine color on servers or databases", vim.log.levels.WARN)
    return
  end

  -- Get the name to use for color lookup
  local name = nil
  if is_server then
    -- For servers, use server name from connection string
    local ConnectionString = require('ssns.connection_string')
    local parsed = ConnectionString.parse(obj.connection_string)

    if parsed.scheme == "sqlite" then
      -- For SQLite, use the full file path
      -- Note: The parser incorrectly splits Windows paths into host/instance/path
      if parsed.host then
        name = parsed.host
        if parsed.instance then
          -- Reconstruct full path from split parts
          name = name .. "/" .. parsed.instance
        end
        if parsed.path then
          name = name .. parsed.path
        end
        -- Normalize backslashes to forward slashes for consistency
        name = name:gsub("\\", "/")
      elseif parsed.path then
        -- Just path (remove leading slash)
        name = parsed.path:match("^/(.*)") or parsed.path
        name = name:gsub("\\", "/")
      else
        name = ":memory:"
      end
    elseif parsed.host then
      -- Build server name: host[\instance]
      name = parsed.host
      if parsed.instance then
        name = name .. "\\" .. parsed.instance
      end
    end
  elseif is_database then
    -- For databases, use database name
    name = obj.db_name
  end

  if not name then
    vim.notify("SSNS: Could not determine name for color setting", vim.log.levels.ERROR)
    return
  end

  -- Prompt for color
  local LualineColors = require('ssns.lualine_colors')
  LualineColors.prompt_set_color(name, is_server)
end

return UiTree
