---@class UiTree
---Tree rendering and interaction for SSNS
local UiTree = {}

---Line to object mapping (line_number -> object)
---@type table<number, BaseDbObject>
UiTree.line_map = {}

---Object to line mapping (object -> line_number)
---@type table<BaseDbObject, number>
UiTree.object_map = {}

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
end

---Render a server and its children
---@param server ServerClass
---@param lines string[]
---@param line_number number
---@param indent_level number
function UiTree.render_server(server, lines, line_number, indent_level)
  local indent = string.rep("  ", indent_level)
  local icon = server.ui_state.expanded and "▾ " or "▸ "
  local status = server:get_status_icon()

  -- Server line
  local line = string.format("%s%s%s %s", indent, icon, server.name, status)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = server
  UiTree.object_map[server] = #lines

  -- If expanded, render children (Databases group, etc.)
  if server.ui_state.expanded then
    if server.is_loaded and server:has_children() then
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
      -- Show loading indicator
      table.insert(lines, indent .. "    Loading...")
    end
  end
end

---Render a database and its children
---@param db DbClass
---@param lines string[]
---@param indent_level number
function UiTree.render_database(db, lines, indent_level)
  local indent = string.rep("  ", indent_level)
  local icon = db.ui_state.expanded and "▾ " or "▸ "
  local status = db:get_status_icon()

  -- Database line
  local line = string.format("%s%s%s %s", indent, icon, db.name, status)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = db
  UiTree.object_map[db] = #lines

  -- If expanded, render object type groups (TABLES, VIEWS, etc.)
  if db.ui_state.expanded then
    if db.is_loaded and db:has_children() then
      -- Render each object type group
      for _, group in ipairs(db.children) do
        UiTree.render_object(group, lines, indent_level + 1)
      end
    else
      table.insert(lines, indent .. "    Loading...")
    end
  end
end

---Render a schema and its children
---@param schema SchemaClass
---@param lines string[]
---@param indent_level number
function UiTree.render_schema(schema, lines, indent_level)
  local indent = string.rep("  ", indent_level)
  local icon = schema.ui_state.expanded and "▾ " or "▸ "

  -- Schema line
  local line = string.format("%s%s%s", indent, icon, schema.name)
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
      table.insert(lines, indent .. "    Loading...")
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
  local indent = string.rep("  ", indent_level)

  -- Check if this is an action or detail node
  if obj.object_type == "action" then
    -- Action nodes (SELECT, DROP, etc.)
    local line = string.format("%s  %s", indent, obj.name)
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
    or obj.object_type == "databases_group"
    or obj.object_type == "tables_group"
    or obj.object_type == "views_group"
    or obj.object_type == "procedures_group"
    or obj.object_type == "functions_group"
    or obj.object_type == "column_group"
    or obj.object_type == "index_group"
    or obj.object_type == "key_group"
    or obj.object_type == "parameter_group"

  local icon = ""
  if has_children then
    icon = obj.ui_state.expanded and "▾ " or "▸ "
  end

  -- Object line
  local display_name = obj.get_display_name and obj:get_display_name() or obj.name
  local line = string.format("%s%s%s", indent, icon, display_name)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = obj
  UiTree.object_map[obj] = #lines

  -- If expanded, render children
  if obj.ui_state.expanded then
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

  -- Second pass: Render with aligned columns
  for i, row in ipairs(formatted_rows) do
    local parts = {}
    for idx, value in ipairs(row) do
      local width = max_widths[idx] or #value
      local padded = value .. string.rep(" ", width - #value)
      table.insert(parts, padded)
    end

    -- Add extra spacing to align with action nodes (which have "  " prefix for no arrow)
    local line = indent .. "  " .. table.concat(parts, " | ")
    table.insert(lines, line)

    -- Map line to the original child object
    UiTree.line_map[#lines] = children[i]
    UiTree.object_map[children[i]] = #lines
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

  -- Toggle expansion
  obj:toggle_expand()

  -- Re-render tree
  UiTree.render()

  -- Restore cursor position
  Buffer.set_cursor(line_number)
end

---Execute an action node
---@param action BaseDbObject
function UiTree.execute_action(action)
  local Query = require('ssns.ui.query')
  local parent = action.parent

  -- Navigate up past groups to find actual parent object
  while parent and (parent.object_type == "column_group" or parent.object_type == "index_group" or parent.object_type == "key_group") do
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
      Query.create_query_buffer(server, database, sql)
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
        Query.create_query_buffer(server, database, sql)
      end
    end
  elseif action.action_type == "exec" then
    -- Generate EXEC statement
    if parent.generate_exec then
      local sql = parent:generate_exec()
      Query.create_query_buffer(server, database, sql)
    end
  elseif action.action_type == "alter" then
    -- Show definition (ALTER displays the object definition)
    if parent.get_definition then
      local definition = parent:get_definition()
      if definition then
        Query.create_query_buffer(server, database, definition)
      else
        vim.notify("No definition available", vim.log.levels.WARN)
      end
    end
  elseif action.action_type == "dependencies" then
    -- Show dependencies
    UiTree.show_dependencies(parent)
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
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Reload the object
  if obj.reload then
    obj:reload()
    vim.notify(string.format("Refreshed %s", obj.name), vim.log.levels.INFO)
  end

  -- Re-render tree
  UiTree.render()

  -- Restore cursor position
  Buffer.set_cursor(line_number)
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

    -- Restore cursor position
    Buffer.set_cursor(line_number)
  else
    vim.notify("Can only toggle connection on servers/databases", vim.log.levels.WARN)
  end
end

return UiTree
