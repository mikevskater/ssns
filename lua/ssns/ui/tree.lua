---@class UiTree
---Tree rendering and interaction for SSNS
local UiTree = {}

---Line to object mapping (line_number -> object)
---@type table<number, BaseDbObject>
UiTree.line_map = {}

---Object to line mapping (object -> line_number)
---@type table<BaseDbObject, number>
UiTree.object_map = {}

---Create an ephemeral UI group for display (not stored in data model)
---@param parent BaseDbObject Parent object
---@param name string Base name for the group (e.g., "TABLES")
---@param object_type string Group type (e.g., "tables_group")
---@param items table[] Array of child objects
---@return table group Ephemeral group object
local function create_ui_group(parent, name, object_type, items)
  local BaseDbObject = require('ssns.classes.base')

  -- Create a minimal group object for UI display
  local group = setmetatable({}, { __index = BaseDbObject })
  group.name = name
  group.object_type = object_type
  group.parent = parent
  group.children = items or {}
  group.is_loaded = true
  group._is_ephemeral = true  -- Mark as ephemeral for special handling

  -- Initialize UI state
  group.ui_state = {
    expanded = parent["_ui_" .. object_type .. "_expanded"] or false,
    visible = true,
    icon = nil,
    highlight = nil,
    loading = false,
    error = nil,
  }

  -- Add minimal methods needed for rendering
  function group:has_children()
    return #self.children > 0
  end

  function group:get_children()
    return self.children
  end

  function group:toggle_expand()
    self.ui_state.expanded = not self.ui_state.expanded
    -- Store expansion state on parent for persistence
    if self.parent then
      self.parent["_ui_" .. self.object_type .. "_expanded"] = self.ui_state.expanded
    end
  end

  return group
end

---Get all objects from a schema combined into a single sorted list
---@param schema SchemaClass The schema to get objects from
---@return BaseDbObject[] all_objects Combined and sorted list of all objects
local function get_schema_all_objects(schema)
  local all_objects = {}

  -- Collect from all typed arrays
  for _, t in ipairs(schema:get_tables() or {}) do table.insert(all_objects, t) end
  for _, v in ipairs(schema:get_views() or {}) do table.insert(all_objects, v) end
  for _, p in ipairs(schema:get_procedures() or {}) do table.insert(all_objects, p) end
  for _, f in ipairs(schema:get_functions() or {}) do table.insert(all_objects, f) end
  for _, s in ipairs(schema:get_synonyms() or {}) do table.insert(all_objects, s) end

  -- Sort alphabetically by name (case-insensitive)
  table.sort(all_objects, function(a, b)
    return (a.name or ""):lower() < (b.name or ""):lower()
  end)

  return all_objects
end

---Get icon for object type
---@param object_type string
---@param icons table
---@param obj BaseDbObject? Optional object for special handling
---@return string
function UiTree.get_object_icon(object_type, icons, obj)
  -- Special handling for object references - use the referenced object's icon
  if object_type == "object_reference" and obj and obj.referenced_object then
    object_type = obj.referenced_object.object_type
  end

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
    schemas_group = icons.schema or "",
    column_group = icons.schema or "",
    index_group = icons.schema or "",
    key_group = icons.schema or "",
    parameter_group = icons.schema or "",
    actions_group = icons.schema or "",
    -- Schema nodes
    schema_view = icons.schema or "",
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
    elseif server.is_loaded then
      -- Get databases using typed array accessor
      local databases = server:get_databases()
      if #databases > 0 then
        -- Create ephemeral databases group for UI
        local databases_group = create_ui_group(server, "Databases", "databases_group", databases)
        UiTree.render_object(databases_group, lines, indent_level + 1)
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
    elseif db.is_loaded then
      -- Render object groups at database level (aggregating from schemas if needed)
      -- This works for both schema-based (SQL Server, PostgreSQL) and non-schema (MySQL) servers
      local adapter = db:get_adapter()

      -- TABLES group - uses db:get_tables() which aggregates from schemas
      -- Always show even if empty (with count of 0)
      local tables = db:get_tables()
      local tables_group = create_ui_group(db, "TABLES", "tables_group", tables)
      UiTree.render_object(tables_group, lines, indent_level + 1)

      -- VIEWS group - always show if feature supported
      if adapter.features and adapter.features.views then
        local views = db:get_views()
        local views_group = create_ui_group(db, "VIEWS", "views_group", views)
        UiTree.render_object(views_group, lines, indent_level + 1)
      end

      -- PROCEDURES group - always show if feature supported
      if adapter.features and adapter.features.procedures then
        local procedures = db:get_procedures()
        local procedures_group = create_ui_group(db, "PROCEDURES", "procedures_group", procedures)
        UiTree.render_object(procedures_group, lines, indent_level + 1)
      end

      -- FUNCTIONS group - always show if feature supported
      if adapter.features and adapter.features.functions then
        local functions = db:get_functions()
        local functions_group = create_ui_group(db, "FUNCTIONS", "functions_group", functions)
        UiTree.render_object(functions_group, lines, indent_level + 1)
      end

      -- SYNONYMS group (typically SQL Server only) - always show if feature supported
      if adapter.features and adapter.features.synonyms then
        local synonyms = db:get_synonyms()
        local synonyms_group = create_ui_group(db, "SYNONYMS", "synonyms_group", synonyms)
        UiTree.render_object(synonyms_group, lines, indent_level + 1)
      end

      -- SCHEMAS group (for schema-based servers like SQL Server, PostgreSQL)
      -- Shown last as an alternative view of objects organized by schema
      if adapter.features and adapter.features.schemas then
        local schemas = db:get_schemas()
        local schemas_group = create_ui_group(db, "SCHEMAS", "schemas_group", schemas)
        UiTree.render_object(schemas_group, lines, indent_level + 1)
      end
    else
      local loading_icon = icons.connecting or "⋯"
      table.insert(lines, indent .. "    " .. loading_icon .. " Loading...")
    end
  end
end

---Render a schema and its children (flat list sorted by name)
---@param schema SchemaClass
---@param lines string[]
---@param indent_level number
function UiTree.render_schema(schema, lines, indent_level)
  local Config = require('ssns.config')
  local UiFilters = require('ssns.ui.filters')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = schema.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  local schema_icon = icons.schema or ""

  -- Get all objects combined and sorted for count display
  local all_objects = {}
  local count_display = ""
  if schema.is_loaded then
    all_objects = get_schema_all_objects(schema)

    -- Apply filters to get filtered list and effective total
    local filters = UiFilters.get(schema)
    local filtered_objects, effective_total = UiFilters.apply(all_objects, filters)
    local filtered_count = #filtered_objects

    -- Get count display (shows "x/y" if filtered, or just "x" if not)
    count_display = " " .. UiFilters.get_count_display(schema, filtered_count, effective_total)

    -- Store filtered objects for rendering children
    all_objects = filtered_objects
  end

  -- Schema line with icon and count
  local line = string.format("%s%s %s %s%s", indent, expand_icon, schema_icon, schema.name, count_display)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = schema
  UiTree.object_map[schema] = #lines

  -- If expanded, render all objects as flat sorted list
  if schema.ui_state.expanded then
    if schema.is_loaded then
      -- Render each object directly (no intermediate groups)
      for _, obj in ipairs(all_objects) do
        UiTree.render_object(obj, lines, indent_level + 1)
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
  local UiFilters = require('ssns.ui.filters')
  local indent = string.rep("  ", indent_level)
  local icon = group.ui_state.expanded and "▾ " or "▸ "

  -- Get all children
  local all_children = group:has_children() and group:get_children() or {}

  -- Apply filters if any
  local filters = UiFilters.get(group)
  local filtered_children, total_count, filter_error = UiFilters.apply(all_children, filters)
  local filtered_count = #filtered_children

  -- Show filter error if any
  if filter_error then
    vim.notify(string.format("SSNS: Filter error on %s: %s", group.name, filter_error), vim.log.levels.WARN)
  end

  -- Group line with count display
  -- Strip any existing count from name (in case it's already there)
  local base_name = group.name:gsub("%s*%([%d/]+%)$", "")
  local count_display = UiFilters.get_count_display(group, filtered_count, total_count)
  local line = string.format("%s%s%s %s", indent, icon, base_name, count_display)
  table.insert(lines, line)

  -- Map line to object
  UiTree.line_map[#lines] = group
  UiTree.object_map[group] = #lines

  -- If expanded, render filtered children
  if group.ui_state.expanded and #filtered_children > 0 then
    for _, child in ipairs(filtered_children) do
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
    or obj.object_type == "schemas_group"
    or obj.object_type == "schema_view"
    or obj.object_type == "column_group"
    or obj.object_type == "index_group"
    or obj.object_type == "key_group"
    or obj.object_type == "parameter_group"
    or obj.object_type == "actions_group"
    -- Object references show expand arrow if their referenced object can have children
    or (obj.object_type == "object_reference" and obj.referenced_object
        and (obj.referenced_object.object_type == "table"
             or obj.referenced_object.object_type == "view"
             or obj.referenced_object.object_type == "procedure"
             or obj.referenced_object.object_type == "function"
             or obj.referenced_object.object_type == "synonym"))

  local expand_icon = ""
  if has_children then
    expand_icon = obj.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  end

  -- Get object-type specific icon
  local obj_icon = UiTree.get_object_icon(obj.object_type, icons, obj)

  -- Check if this is a schema node or object group
  local is_schema_node = obj.object_type == "schema" or obj.object_type == "schema_view"
  local is_object_group = obj.object_type == "databases_group" or
                          obj.object_type == "tables_group" or
                          obj.object_type == "views_group" or
                          obj.object_type == "procedures_group" or
                          obj.object_type == "functions_group" or
                          obj.object_type == "synonyms_group" or
                          obj.object_type == "sequences_group"

  -- For groups and schemas, use name directly and add count
  -- For other objects, use get_display_name if available
  local display_name
  if is_schema_node or is_object_group then
    -- Strip any existing count from name (in case it's already there)
    local base_name = obj.name:gsub("%s*%([%d/]+%)$", "")
    display_name = base_name
    if obj:has_children() then
      local UiFilters = require('ssns.ui.filters')
      local filters = UiFilters.get(obj)
      local all_children = obj:get_children()
      local filtered_children = UiFilters.apply(all_children, filters)
      local count_display = UiFilters.get_count_display(obj, #filtered_children, #all_children)
      display_name = display_name .. " " .. count_display
    end
  else
    display_name = obj.get_display_name and obj:get_display_name() or obj.name
  end

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
        local all_children = obj:get_children()

        -- Apply filtering for schema nodes or object groups
        local is_schema_node = obj.object_type == "schema" or obj.object_type == "schema_view"
        local is_object_group = obj.object_type == "databases_group" or
                                obj.object_type == "tables_group" or
                                obj.object_type == "views_group" or
                                obj.object_type == "procedures_group" or
                                obj.object_type == "functions_group" or
                                obj.object_type == "synonyms_group" or
                                obj.object_type == "sequences_group"

        if is_schema_node or is_object_group then
          local UiFilters = require('ssns.ui.filters')
          local filters = UiFilters.get(obj)
          local filtered_children, total_count, filter_error = UiFilters.apply(all_children, filters)

          -- Show filter error if any
          if filter_error then
            vim.notify(string.format("SSNS: Filter error on %s: %s", obj.name, filter_error), vim.log.levels.WARN)
          end

          -- Render filtered children
          for _, child in ipairs(filtered_children) do
            -- Delegate to specialized renderers for complex objects
            if child.object_type == "database" then
              UiTree.render_database(child, lines, indent_level + 1)
            elseif child.object_type == "schema" then
              UiTree.render_schema(child, lines, indent_level + 1)
            else
              UiTree.render_object(child, lines, indent_level + 1)
            end
          end
        else
          -- Regular rendering without filters
          for _, child in ipairs(all_children) do
            -- Delegate to specialized renderers for complex objects
            if child.object_type == "database" then
              UiTree.render_database(child, lines, indent_level + 1)
            elseif child.object_type == "schema" then
              UiTree.render_schema(child, lines, indent_level + 1)
            else
              UiTree.render_object(child, lines, indent_level + 1)
            end
          end
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
    local obj_icon = UiTree.get_object_icon(child.object_type, icons, child)

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

  -- If parent is an object_reference, it already proxies all methods to the referenced object
  -- so we can use it directly without dereferencing

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
    -- Generate EXEC statement with parameter prompts if needed
    if parent.generate_exec then
      -- Load parameters to check if we need prompts
      if parent.load_parameters then
        parent:load_parameters()
      end

      local parameters = parent.parameters or {}

      -- Filter to only input parameters (IN or INOUT)
      local input_params = {}
      for _, param in ipairs(parameters) do
        if param.direction == "IN" or param.direction == "INOUT" then
          table.insert(input_params, param)
        end
      end

      if #input_params > 0 then
        -- Show parameter input UI BEFORE creating buffer
        local UiParamInput = require('ssns.ui.param_input')
        local proc_name = (parent.schema_name and parent.schema_name .. "." or "") .. parent.procedure_name

        UiParamInput.show_input(
          proc_name,
          server.name,
          database and database.db_name or nil,
          input_params,
          function(values)
            -- Build EXEC statement with user-provided values
            local UiQuery = require('ssns.ui.query')
            local sql = UiQuery.build_exec_statement(parent.schema_name, parent.procedure_name, input_params, values)

            -- Create buffer with the fully-formed EXEC statement
            Query.create_query_buffer(server, database, sql, parent.name)
          end
        )
      else
        -- No parameters, create buffer with simple EXEC
        local sql = parent:generate_exec()
        Query.create_query_buffer(server, database, sql, parent.name)
      end
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

---Navigate to an object in the tree (expand parents and position cursor)
---Auto-loads unloaded objects in the path and expands them
---@param target_object BaseDbObject The object to navigate to
function UiTree.navigate_to_object(target_object)
  if not target_object then
    vim.notify("No object to navigate to", vim.log.levels.WARN)
    return
  end

  -- Collect all parents up to root (for cross-database, go to target database's tree)
  local parents = {}
  local current = target_object
  while current do
    table.insert(parents, 1, current)  -- Insert at beginning to get root-to-target order
    current = current.parent
  end

  -- Load and expand all parent nodes in order (root to target)
  for _, parent in ipairs(parents) do
    -- First, load the object if it has a load method and isn't loaded
    if not parent.is_loaded and parent.load then
      parent:load()
    end

    -- Then expand if it can have children (by type or by actual children)
    local can_have_children = parent:has_children()
      or parent.object_type == "server"
      or parent.object_type == "database"
      or parent.object_type == "schema"
      or parent.object_type == "table"
      or parent.object_type == "view"
      or parent.object_type == "procedure"
      or parent.object_type == "function"
      or parent.object_type == "synonym"
      or parent.object_type == "databases_group"
      or parent.object_type == "tables_group"
      or parent.object_type == "views_group"
      or parent.object_type == "procedures_group"
      or parent.object_type == "functions_group"
      or parent.object_type == "synonyms_group"
      or parent.object_type == "schemas_group"

    if not parent.ui_state.expanded and can_have_children then
      parent.ui_state.expanded = true
    end
  end

  -- Find the database that contains the target object
  local database = target_object:get_database()
  if not database then
    vim.notify("Target database not found", vim.log.levels.WARN)
    return
  end

  -- Load the database if not loaded
  if not database.is_loaded and database.load then
    database:load()
  end

  -- Verify object exists in cached data using typed arrays
  local group_type = nil
  local object_exists = false

  -- Helper to check if object exists in a collection
  local function find_in_collection(collection)
    for _, obj in ipairs(collection or {}) do
      if obj == target_object then
        return true
      end
    end
    return false
  end

  if target_object.object_type == "table" then
    group_type = "tables_group"
    object_exists = find_in_collection(database:get_tables())
  elseif target_object.object_type == "view" then
    group_type = "views_group"
    object_exists = find_in_collection(database:get_views())
  elseif target_object.object_type == "procedure" then
    group_type = "procedures_group"
    object_exists = find_in_collection(database:get_procedures())
  elseif target_object.object_type == "function" then
    group_type = "functions_group"
    object_exists = find_in_collection(database:get_functions())
  elseif target_object.object_type == "synonym" then
    group_type = "synonyms_group"
    object_exists = find_in_collection(database:get_synonyms())
  end

  -- Object doesn't exist in cached data - don't expand
  if not object_exists then
    vim.notify(string.format("Object '%s' not found in database (may have been dropped)", target_object.name), vim.log.levels.WARN)
    return
  end

  -- Object exists - store expansion state for the ephemeral group
  -- (The ephemeral group will read this when created during render)
  if group_type then
    -- Get the schema if object has one (for schema-based servers)
    local schema = target_object.parent
    if schema and schema.object_type == "schema" then
      -- Expand the schema and its group
      schema.ui_state.expanded = true
      schema["_ui_" .. group_type .. "_expanded"] = true
    else
      -- Non-schema server: expand database's group
      database["_ui_" .. group_type .. "_expanded"] = true
    end
  end

  -- Re-render tree to show all expanded nodes
  UiTree.render()

  -- Find the line number for the target object
  local target_line = UiTree.object_map[target_object]
  if not target_line then
    vim.notify("Object not found in tree after expansion", vim.log.levels.WARN)
    return
  end

  -- Position cursor on the target object with smart positioning
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  -- Use smart positioning to align cursor at object name start
  local col = smart_positioning and Buffer.get_name_column(target_line) or 0
  Buffer.set_cursor(target_line, col)

  -- Update indent tracking for smart positioning
  if smart_positioning then
    Buffer.last_indent_info = {
      line = target_line,
      indent_level = Buffer.get_indent_level(target_line),
      column = col,
    }
  end

  vim.notify(string.format("Navigated to %s", target_object.name), vim.log.levels.INFO)
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

---Open filter editor for the current group
function UiTree.open_filter()
  local Buffer = require('ssns.ui.buffer')

  local line = Buffer.get_current_line()
  if not line then
    return
  end

  local obj = UiTree.line_map[line]
  if not obj then
    vim.notify("SSNS: No object at current line", vim.log.levels.WARN)
    return
  end

  -- Check if this is a filterable object (group or schema node)
  local filterable_types = {
    "databases_group", "tables_group", "views_group", "procedures_group", "functions_group",
    "synonyms_group", "sequences_group", "schema", "schema_view"  -- Individual schema nodes, not schemas_group
  }

  local is_filterable = false
  for _, type_name in ipairs(filterable_types) do
    if obj.object_type == type_name then
      is_filterable = true
      break
    end
  end

  if not is_filterable then
    vim.notify("SSNS: Filters can only be applied to object groups or schema nodes", vim.log.levels.WARN)
    return
  end

  -- Open filter input UI
  local UiFilterInput = require('ssns.ui.filter_input')
  local UiFilters = require('ssns.ui.filters')
  local current_filters = UiFilters.get(obj)

  UiFilterInput.show_input(obj, current_filters, function(filter_state)
    -- Apply filters
    UiFilters.set(obj, filter_state)
    -- Re-render tree
    UiTree.render()
  end)
end

---Clear filters for the current group
function UiTree.clear_filter()
  local Buffer = require('ssns.ui.buffer')

  local line = Buffer.get_current_line()
  if not line then
    return
  end

  local obj = UiTree.line_map[line]
  if not obj then
    vim.notify("SSNS: No object at current line", vim.log.levels.WARN)
    return
  end

  -- Check if this is a filterable object (group or schema node)
  local filterable_types = {
    "databases_group", "tables_group", "views_group", "procedures_group", "functions_group",
    "synonyms_group", "sequences_group", "schema", "schema_view"  -- Individual schema nodes, not schemas_group
  }

  local is_filterable = false
  for _, type_name in ipairs(filterable_types) do
    if obj.object_type == type_name then
      is_filterable = true
      break
    end
  end

  if not is_filterable then
    vim.notify("SSNS: Filters can only be cleared on object groups or schema nodes", vim.log.levels.WARN)
    return
  end

  -- Clear filters
  local UiFilters = require('ssns.ui.filters')
  UiFilters.clear(obj)

  -- Refresh tree
  UiTree.render()

  vim.notify("SSNS: Filters cleared", vim.log.levels.INFO)
end

---Go to the first child in the current group
---If on a group node, goes to its first child
---If on a child within a group, goes to the first sibling
function UiTree.goto_first_child()
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_obj = nil

  -- Check if current object is a group (has children and is expanded)
  if obj.ui_state and obj.ui_state.expanded and obj:has_children() then
    -- On a group node - go to first child
    local children = obj:get_children()
    if #children > 0 then
      -- Apply filters if this is a filterable group
      local UiFilters = require('ssns.ui.filters')
      local filters = UiFilters.get(obj)
      local filtered_children = UiFilters.apply(children, filters)
      if #filtered_children > 0 then
        target_obj = filtered_children[1]
      end
    end
  elseif obj.parent then
    -- On a child within a group - go to first sibling
    local parent = obj.parent
    if parent:has_children() then
      local siblings = parent:get_children()
      -- Apply filters if parent is a filterable group
      local UiFilters = require('ssns.ui.filters')
      local filters = UiFilters.get(parent)
      local filtered_siblings = UiFilters.apply(siblings, filters)
      if #filtered_siblings > 0 then
        target_obj = filtered_siblings[1]
      end
    end
  end

  if target_obj then
    local target_line = UiTree.object_map[target_obj]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Go to the last child in the current group
---If on a group node, goes to its last child
---If on a child within a group, goes to the last sibling
function UiTree.goto_last_child()
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_obj = nil

  -- Check if current object is a group (has children and is expanded)
  if obj.ui_state and obj.ui_state.expanded and obj:has_children() then
    -- On a group node - go to last child
    local children = obj:get_children()
    if #children > 0 then
      -- Apply filters if this is a filterable group
      local UiFilters = require('ssns.ui.filters')
      local filters = UiFilters.get(obj)
      local filtered_children = UiFilters.apply(children, filters)
      if #filtered_children > 0 then
        target_obj = filtered_children[#filtered_children]
      end
    end
  elseif obj.parent then
    -- On a child within a group - go to last sibling
    local parent = obj.parent
    if parent:has_children() then
      local siblings = parent:get_children()
      -- Apply filters if parent is a filterable group
      local UiFilters = require('ssns.ui.filters')
      local filters = UiFilters.get(parent)
      local filtered_siblings = UiFilters.apply(siblings, filters)
      if #filtered_siblings > 0 then
        target_obj = filtered_siblings[#filtered_siblings]
      end
    end
  end

  if target_obj then
    local target_line = UiTree.object_map[target_obj]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Toggle expand/collapse of the parent group
---If on a group node, toggles that group
---If on a child within a group, toggles the parent group and moves cursor to it
function UiTree.toggle_group()
  local Buffer = require('ssns.ui.buffer')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    return
  end

  local target_group = nil

  -- Check if current object is a group (can be expanded/collapsed)
  if obj.ui_state and obj:has_children() then
    -- Current object is a group - toggle it directly
    target_group = obj
  elseif obj.parent then
    -- Find the nearest parent that is a group (can be expanded/collapsed)
    local parent = obj.parent
    while parent do
      if parent.ui_state and parent:has_children() then
        target_group = parent
        break
      end
      parent = parent.parent
    end
  end

  if target_group then
    -- Toggle the group's expansion state
    target_group:toggle_expand()

    -- Re-render tree
    UiTree.render()

    -- Find the line of the target group and position cursor there
    local target_line = UiTree.object_map[target_group]
    if target_line then
      local col = smart_positioning and Buffer.get_name_column(target_line) or 0
      Buffer.set_cursor(target_line, col)
      -- Update indent tracking
      if smart_positioning then
        Buffer.last_indent_info = {
          line = target_line,
          indent_level = Buffer.get_indent_level(target_line),
          column = col,
        }
      end
    end
  end
end

---Create a new query buffer using the database context from the current tree node
function UiTree.new_query_from_context()
  local Buffer = require('ssns.ui.buffer')
  local Query = require('ssns.ui.query')
  local Cache = require('ssns.cache')

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  local server, database

  if obj then
    -- Get database and server from the hovered object's hierarchy
    database = obj:get_database()
    server = obj:get_server()
  end

  -- Fallback: if hovering on server or no object, try active database
  if not database then
    database = Cache.get_active_database()
    if database then
      server = database:get_server()
    end
  end

  -- Final fallback: just get first connected server
  if not server then
    local servers = Cache.get_all_servers()
    for _, s in ipairs(servers) do
      if s:is_connected() then
        server = s
        break
      end
    end
  end

  -- Create buffer (USE statement is handled inside create_query_buffer)
  Query.create_query_buffer(server, database, "", "Query")
end

return UiTree
