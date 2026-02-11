---@class TreeRender
---Tree rendering functions for SSNS
---Extracted from ui/core/tree.lua
local TreeRender = {}

local ContentBuilder = require('nvim-float.content')

---Create an ephemeral UI group for display (not stored in data model)
---@param parent BaseDbObject Parent object
---@param name string Base name for the group (e.g., "TABLES")
---@param object_type string Group type (e.g., "tables_group")
---@param items table[] Array of child objects
---@return table group Ephemeral group object
function TreeRender.create_ui_group(parent, name, object_type, items)
  local BaseDbObject = require('nvim-ssns.classes.base')

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

---Collect all objects from a schema (unsorted)
---@param schema SchemaClass The schema to get objects from
---@return BaseDbObject[] all_objects Combined list of all objects (unsorted)
function TreeRender.collect_schema_objects(schema)
  local all_objects = {}

  -- Collect from all typed arrays
  for _, t in ipairs(schema:get_tables() or {}) do table.insert(all_objects, t) end
  for _, v in ipairs(schema:get_views() or {}) do table.insert(all_objects, v) end
  for _, p in ipairs(schema:get_procedures() or {}) do table.insert(all_objects, p) end
  for _, f in ipairs(schema:get_functions() or {}) do table.insert(all_objects, f) end
  for _, s in ipairs(schema:get_synonyms() or {}) do table.insert(all_objects, s) end

  return all_objects
end

---Get all objects from a schema combined into a single sorted list (sync fallback)
---@param schema SchemaClass The schema to get objects from
---@return BaseDbObject[] all_objects Combined and sorted list of all objects
function TreeRender.get_schema_all_objects(schema)
  local all_objects = TreeRender.collect_schema_objects(schema)

  -- Sort alphabetically by name (case-insensitive)
  table.sort(all_objects, function(a, b)
    return (a.name or ""):lower() < (b.name or ""):lower()
  end)

  return all_objects
end

---Start async sorting of schema objects
---Caches sorted result on schema and triggers re-render when complete
---@param schema SchemaClass The schema to sort objects for
---@param opts { on_complete: function?, bufnr: number?, line: number? }? Options
function TreeRender.sort_schema_objects_async(schema, opts)
  opts = opts or {}
  local Thread = require('nvim-ssns.async.thread')
  local Spinner = require('nvim-ssns.async.spinner')

  -- Stop any existing spinner for this schema
  if schema._sort_spinner_id then
    Spinner.stop(schema._sort_spinner_id)
    schema._sort_spinner_id = nil
  end

  -- Check if threading is available
  if not Thread.is_available() then
    -- Fallback to sync sorting
    schema._sorted_objects = TreeRender.get_schema_all_objects(schema)
    schema._sorting = false
    if opts.on_complete then opts.on_complete() end
    return
  end

  -- Mark as sorting
  schema._sorting = true
  schema._sorted_objects = nil

  -- Start spinner if buffer info provided
  if opts.bufnr and opts.line and vim.api.nvim_buf_is_valid(opts.bufnr) then
    schema._sort_spinner_id = Spinner.start_in_buffer(opts.bufnr, {
      line = opts.line,
      text = "    Sorting " .. schema.name,
      style = "braille",
      show_runtime = true,
    })
  end

  -- Collect unsorted objects
  local all_objects = TreeRender.collect_schema_objects(schema)

  -- If empty, no need to sort
  if #all_objects == 0 then
    schema._sorted_objects = {}
    schema._sorting = false
    if schema._sort_spinner_id then
      Spinner.stop(schema._sort_spinner_id)
      schema._sort_spinner_id = nil
    end
    if opts.on_complete then opts.on_complete() end
    return
  end

  -- Prepare items for thread (minimal serializable data + index for reconstruction)
  local items = {}
  for i, obj in ipairs(all_objects) do
    table.insert(items, {
      idx = i,
      name = obj.name or "",
      object_type = obj.object_type,
    })
  end

  -- Sorted result accumulator
  local sorted_indices = {}

  -- Start threaded sort
  Thread.start({
    worker = "sort",
    input = {
      items = items,
      key_field = "name",
      descending = false,
    },
    on_batch = function(batch)
      -- Accumulate sorted indices
      for _, item in ipairs(batch.items or {}) do
        table.insert(sorted_indices, item.idx)
      end
    end,
    on_complete = function(result, err)
      -- Stop spinner
      vim.schedule(function()
        if schema._sort_spinner_id then
          Spinner.stop(schema._sort_spinner_id)
          schema._sort_spinner_id = nil
        end
      end)

      if err then
        -- On error, fallback to sync sort
        vim.schedule(function()
          schema._sorted_objects = TreeRender.get_schema_all_objects(schema)
          schema._sorting = false
          if opts.on_complete then opts.on_complete() end
        end)
        return
      end

      -- Reconstruct sorted objects from indices
      vim.schedule(function()
        local sorted = {}
        for _, idx in ipairs(sorted_indices) do
          if all_objects[idx] then
            table.insert(sorted, all_objects[idx])
          end
        end
        schema._sorted_objects = sorted
        schema._sorting = false
        if opts.on_complete then opts.on_complete() end
      end)
    end,
  })
end

---Invalidate cached sorted objects for a schema
---Call this when schema contents change
---@param schema SchemaClass
function TreeRender.invalidate_schema_cache(schema)
  -- Stop any running spinner
  if schema._sort_spinner_id then
    local Spinner = require('nvim-ssns.async.spinner')
    Spinner.stop(schema._sort_spinner_id)
    schema._sort_spinner_id = nil
  end

  schema._sorted_objects = nil
  schema._sorting = false
end

---Get highlight style for object type
---@param object_type string
---@return string style The highlight group name
function TreeRender.get_object_style(object_type)
  local style_map = {
    -- Main objects
    server = "SsnsServer",
    database = "SsnsDatabase",
    schema = "SsnsSchema",
    table = "SsnsTable",
    view = "SsnsView",
    procedure = "SsnsProcedure",
    ["function"] = "SsnsFunction",
    synonym = "SsnsSynonym",
    sequence = "SsnsSequence",
    -- Child objects
    column = "SsnsColumn",
    index = "SsnsIndex",
    key = "SsnsKey",
    constraint = "SsnsConstraint",
    parameter = "SsnsParameter",
    -- Actions
    action = "SsnsAction",
    add_server_action = "SsnsAction",
    -- Groups
    databases_group = "SsnsGroup",
    tables_group = "SsnsGroup",
    views_group = "SsnsGroup",
    procedures_group = "SsnsGroup",
    functions_group = "SsnsGroup",
    scalar_functions_group = "SsnsGroup",
    table_functions_group = "SsnsGroup",
    sequences_group = "SsnsGroup",
    synonyms_group = "SsnsGroup",
    schemas_group = "SsnsGroup",
    system_databases_group = "SsnsGroup",
    system_schemas_group = "SsnsGroup",
    column_group = "SsnsGroup",
    index_group = "SsnsGroup",
    key_group = "SsnsGroup",
    parameter_group = "SsnsGroup",
    actions_group = "SsnsGroup",
    -- Schema nodes
    schema_view = "SsnsSchema",
    -- Object references - use the base object type
    object_reference = "SsnsTable",
  }

  return style_map[object_type] or "Normal"
end

---Get icon for object type
---@param object_type string
---@param icons table
---@param obj BaseDbObject? Optional object for special handling
---@return string
function TreeRender.get_object_icon(object_type, icons, obj)
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
    scalar_functions_group = icons.schema or "",
    table_functions_group = icons.schema or "",
    sequences_group = icons.schema or "",
    synonyms_group = icons.schema or "",
    schemas_group = icons.schema or "",
    system_databases_group = icons.schema or "",
    system_schemas_group = icons.schema or "",
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
---@param UiTree table The main UiTree module (for content_builder access)
---@param opts { on_complete: function? }? Optional options with completion callback
function TreeRender.render(UiTree, opts)
  local Cache = require('nvim-ssns').get_cache()
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local Config = require('nvim-ssns.config')
  local icons = Config.get_ui().icons

  -- Save current cursor position before clearing
  local saved_object = nil
  local saved_line = nil
  local saved_column = nil

  if Buffer.is_open() then
    saved_line = Buffer.get_current_line()
    -- Get saved object from content_builder if available, fallback to line_map
    if UiTree.content_builder then
      -- ContentBuilder uses 0-indexed rows
      local element = UiTree.content_builder:get_element_at(saved_line - 1, 0)
      saved_object = element and element.data and element.data.object
    else
      saved_object = UiTree.line_map[saved_line]
    end
    if saved_object then
      local cursor = vim.api.nvim_win_get_cursor(Buffer.winid)
      saved_column = cursor[2]
    end
  else
    -- Restoring from closed state - use last saved state
    saved_object = UiTree.last_cursor_state.object
    saved_line = UiTree.last_cursor_state.line
    saved_column = UiTree.last_cursor_state.column
  end

  -- Clear old mappings (kept for backward compatibility during transition)
  UiTree.line_map = {}
  UiTree.object_map = {}

  -- Create ContentBuilder for this render
  local cb = ContentBuilder.new()

  -- Add "+ Add Server" action at the top (always visible)
  local add_server_action = {
    name = "+ Add Server",
    object_type = "add_server_action",
    is_action = true,
    ui_state = {
      expanded = false,
      visible = true,
    },
    has_children = function() return false end,
  }
  local add_icon = icons.action or ""
  cb:spans({
    { text = "  " },
    { text = add_icon .. " + Add Server", style = "SsnsAction",
      track = {
        name = "add_server",
        type = "add_server_action",
        data = { object = add_server_action },
        row_based = true,
      },
    },
  })

  -- Add separator line
  cb:line("")

  -- Get all servers
  local servers = Cache.get_all_servers()

  if #servers == 0 then
    cb:spans({{ text = "No servers connected", style = "Comment" }})
    cb:line("")
    cb:spans({{ text = "Press Enter on '+ Add Server' above", style = "Comment" }})
    cb:spans({{ text = "or add servers in your setup():", style = "Comment" }})
    cb:spans({{ text = "  connections = {", style = "Comment" }})
    cb:spans({{ text = '    my_server = "sqlserver://.\\\\SQLEXPRESS/master"', style = "Comment" }})
    cb:spans({{ text = "  }", style = "Comment" }})
  else
    -- Render each server (indent level 1 to match "+ Add Server" indent)
    for _, server in ipairs(servers) do
      TreeRender.render_server(UiTree, server, cb, 1)
    end
  end

  -- Build lines and highlights from ContentBuilder
  local lines = cb:build_lines()
  local highlights = cb:build_highlights()

  -- Store ContentBuilder for element lookup
  UiTree.content_builder = cb

  -- Also populate line_map for backward compatibility during transition
  local registry = cb:get_registry()
  if registry then
    -- Iterate through all tracked elements and build line_map/object_map
    for _, element in registry:iter() do
      if element.data and element.data.object then
        local line_num = element.row + 1  -- Convert 0-indexed to 1-indexed
        UiTree.line_map[line_num] = element.data.object
        UiTree.object_map[element.data.object] = line_num
      end
    end
  end

  -- Get chunked render threshold from config
  local ui_config = Config.get_ui()
  local threshold = ui_config.chunked_render_threshold or 200

  -- Use chunked rendering for large trees to avoid blocking UI
  if #lines > threshold then
    -- Chunked write with highlights applied after
    Buffer.set_lines_chunked(lines, {
      chunk_size = 100,
      on_complete = function()
        -- Apply highlights from ContentBuilder
        Buffer.apply_highlights(highlights, {
          batch_size = 100,
          on_complete = function()
            -- Restore cursor position after rendering complete
            if saved_object and Buffer.is_open() then
              UiTree.restore_cursor_to_object(saved_object, saved_column)
            end
            -- Call external completion callback after all rendering is done
            if opts and opts.on_complete then
              opts.on_complete()
            end
          end,
        })
      end,
    })
  else
    -- Sync rendering for small trees
    Buffer.set_lines(lines)
    Buffer.apply_highlights(highlights)

    -- Restore cursor position if we have a saved object
    if saved_object and Buffer.is_open() then
      UiTree.restore_cursor_to_object(saved_object, saved_column)
    end
    -- Call external completion callback after sync rendering is done
    if opts and opts.on_complete then
      opts.on_complete()
    end
  end
end

---Render a server and its children
---@param UiTree table The main UiTree module
---@param server ServerClass
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_server(UiTree, server, cb, indent_level)
  local Config = require('nvim-ssns.config')
  local Connections = require('nvim-ssns.connections')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = server.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")

  -- Get database-type specific server icon and highlight
  local server_icon = icons.server or ""
  local server_style = "SsnsServer"
  local db_type = server:get_db_type()
  if db_type == "sqlserver" then
    server_icon = icons.server_sqlserver or icons.server or ""
    server_style = "SsnsServerSqlServer"
  elseif db_type == "postgres" or db_type == "postgresql" then
    server_icon = icons.server_postgres or icons.server or ""
    server_style = "SsnsServerPostgres"
  elseif db_type == "mysql" then
    server_icon = icons.server_mysql or icons.server or ""
    server_style = "SsnsServerMysql"
  elseif db_type == "sqlite" then
    server_icon = icons.server_sqlite or icons.server or ""
    server_style = "SsnsServerSqlite"
  elseif db_type == "bigquery" then
    server_icon = icons.server_bigquery or icons.server or ""
    server_style = "SsnsServerBigQuery"
  end

  local status = server:get_status_icon()

  -- Check if server is a favorite (show star icon)
  local favorite_icon = ""
  local conn = Connections.find(server.name)
  if conn and (conn.favorite or conn.auto_connect) then
    favorite_icon = " ★"
  end

  -- Server line with icon and element tracking
  cb:spans({
    { text = indent },
    { text = expand_icon .. " " .. server_icon .. " " .. server.name .. favorite_icon .. " " .. status,
      style = server_style,
      track = {
        name = "server_" .. server.name,
        type = "server",
        data = { object = server },
        row_based = true,
      },
    },
  })

  -- If expanded, render children (Databases group, etc.)
  if server.ui_state.expanded then
    if server.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      cb:spans({{ text = indent .. "    " .. error_icon .. " Error: " .. server.ui_state.error, style = "SsnsStatusError" }})
    elseif server.ui_state.loading then
      -- Show loading indicator with server name
      cb:spans({{ text = indent .. "    Loading " .. (server.name or "server") .. "...", style = "SsnsStatusConnecting" }})
    elseif server.is_loaded then
      -- Get databases using typed array accessor
      local all_databases = server:get_databases()
      if #all_databases > 0 then
        -- Get system database names from config
        local filter_config = Config.get_filters()
        local system_db_names = filter_config and filter_config.system_databases or {}

        -- Split into system and user databases
        local system_databases = {}
        local user_databases = {}
        for _, db in ipairs(all_databases) do
          local is_system = false
          for _, sys_name in ipairs(system_db_names) do
            if db.db_name:lower() == sys_name:lower() then
              is_system = true
              break
            end
          end
          if is_system then
            table.insert(system_databases, db)
          else
            table.insert(user_databases, db)
          end
        end

        -- Build children: SYSTEM sub-group first (if any), then user databases
        local children = {}
        if #system_databases > 0 then
          local system_group = TreeRender.create_ui_group(server, "SYSTEM", "system_databases_group", system_databases)
          table.insert(children, system_group)
        end
        for _, db in ipairs(user_databases) do
          table.insert(children, db)
        end

        -- Create parent Databases group with SYSTEM sub-group + user databases as children
        local databases_group = TreeRender.create_ui_group(server, "Databases", "databases_group", children)
        databases_group._total_items = #all_databases
        TreeRender.render_object(UiTree, databases_group, cb, indent_level + 1)
      end
    elseif server:is_connected() and not server.is_loaded then
      -- Show loading indicator (fallback if loading flag not set)
      cb:spans({{ text = indent .. "    Loading " .. (server.name or "server") .. "...", style = "SsnsStatusConnecting" }})
    end
  end
end

---Render a database and its children
---@param UiTree table The main UiTree module
---@param db DbClass
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_database(UiTree, db, cb, indent_level)
  local Config = require('nvim-ssns.config')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = db.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  local db_icon = icons.database or ""
  local status = db:get_status_icon()

  -- Database line with icon and element tracking
  cb:spans({
    { text = indent },
    { text = expand_icon .. " " .. db_icon .. " " .. db.name .. " " .. status,
      style = "SsnsDatabase",
      track = {
        name = "database_" .. db.name,
        type = "database",
        data = { object = db },
        row_based = true,
      },
    },
  })

  -- If expanded, render object type groups (TABLES, VIEWS, etc.)
  if db.ui_state.expanded then
    if db.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      cb:spans({{ text = indent .. "    " .. error_icon .. " Error: " .. db.ui_state.error, style = "SsnsStatusError" }})
    elseif db.ui_state.loading then
      -- Show loading indicator with database name
      cb:spans({{ text = indent .. "    Loading " .. (db.db_name or "database") .. "...", style = "SsnsStatusConnecting" }})
    elseif db.is_loaded then
      -- Render object groups at database level (aggregating from schemas if needed)
      -- This works for both schema-based (SQL Server, PostgreSQL) and non-schema (MySQL) servers
      local adapter = db:get_adapter()

      -- TABLES group - lazy load objects only when group is expanded
      -- Always show even if empty (with count of 0)
      local tables = db:get_tables(nil, { skip_load = true })
      local tables_group = TreeRender.create_ui_group(db, "TABLES", "tables_group", tables)
      TreeRender.render_object(UiTree, tables_group, cb, indent_level + 1)

      -- VIEWS group - always show if feature supported
      if adapter.features and adapter.features.views then
        local views = db:get_views(nil, { skip_load = true })
        local views_group = TreeRender.create_ui_group(db, "VIEWS", "views_group", views)
        TreeRender.render_object(UiTree, views_group, cb, indent_level + 1)
      end

      -- PROCEDURES group - always show if feature supported
      if adapter.features and adapter.features.procedures then
        local procedures = db:get_procedures(nil, { skip_load = true })
        local procedures_group = TreeRender.create_ui_group(db, "PROCEDURES", "procedures_group", procedures)
        TreeRender.render_object(UiTree, procedures_group, cb, indent_level + 1)
      end

      -- FUNCTIONS group - always show if feature supported
      -- Split into SCALAR and TABLE sub-groups
      if adapter.features and adapter.features.functions then
        local all_functions = db:get_functions(nil, { skip_load = true })

        -- Split functions by type
        local scalar_functions = {}
        local table_functions = {}
        for _, func in ipairs(all_functions) do
          if func:is_table_valued() then
            table.insert(table_functions, func)
          else
            table.insert(scalar_functions, func)
          end
        end

        -- Create sub-groups
        local scalar_group = TreeRender.create_ui_group(db, "SCALAR", "scalar_functions_group", scalar_functions)
        local table_group = TreeRender.create_ui_group(db, "TABLE", "table_functions_group", table_functions)

        -- Create parent FUNCTIONS group with sub-groups as children
        local functions_group = TreeRender.create_ui_group(db, "FUNCTIONS", "functions_group", { scalar_group, table_group })
        -- Store total function count for display (not sub-group count)
        functions_group._total_items = #all_functions
        TreeRender.render_object(UiTree, functions_group, cb, indent_level + 1)
      end

      -- SYNONYMS group (typically SQL Server only) - always show if feature supported
      if adapter.features and adapter.features.synonyms then
        local synonyms = db:get_synonyms(nil, { skip_load = true })
        local synonyms_group = TreeRender.create_ui_group(db, "SYNONYMS", "synonyms_group", synonyms)
        TreeRender.render_object(UiTree, synonyms_group, cb, indent_level + 1)
      end

      -- SCHEMAS group (for schema-based servers like SQL Server, PostgreSQL)
      -- Shown last as an alternative view of objects organized by schema
      -- Only load schema names when SCHEMAS group itself is expanded
      if adapter.features and adapter.features.schemas then
        local all_schemas = db:get_schemas()

        -- Get system schema names from config
        local filter_config = Config.get_filters()
        local system_schema_names = filter_config and filter_config.system_schemas or {}

        -- Split into system and user schemas
        local system_schemas = {}
        local user_schemas = {}
        for _, schema in ipairs(all_schemas) do
          local is_system = false
          for _, sys_name in ipairs(system_schema_names) do
            if schema.name:lower() == sys_name:lower() then
              is_system = true
              break
            end
          end
          if is_system then
            table.insert(system_schemas, schema)
          else
            table.insert(user_schemas, schema)
          end
        end

        -- Build children: SYSTEM sub-group first (if any), then user schemas
        local children = {}
        if #system_schemas > 0 then
          local system_group = TreeRender.create_ui_group(db, "SYSTEM", "system_schemas_group", system_schemas)
          table.insert(children, system_group)
        end
        for _, schema in ipairs(user_schemas) do
          table.insert(children, schema)
        end

        -- Create parent SCHEMAS group with SYSTEM sub-group + user schemas as children
        local schemas_group = TreeRender.create_ui_group(db, "SCHEMAS", "schemas_group", children)
        schemas_group._total_items = #all_schemas
        TreeRender.render_object(UiTree, schemas_group, cb, indent_level + 1)
      end
    else
      -- Show loading indicator with database name (fallback)
      cb:spans({{ text = indent .. "    Loading " .. (db.db_name or "database") .. "...", style = "SsnsStatusConnecting" }})
    end
  end
end

---Render a schema and its children (flat list sorted by name)
---Uses async threading for sorting - shows animated spinner while sort is in progress
---@param UiTree table The main UiTree module
---@param schema SchemaClass
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_schema(UiTree, schema, cb, indent_level)
  local Config = require('nvim-ssns.config')
  local UiFilters = require('nvim-ssns.ui.core.filters')
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local icons = Config.get_ui().icons

  local indent = string.rep("  ", indent_level)
  local expand_icon = schema.ui_state.expanded and (icons.expanded or "▾") or (icons.collapsed or "▸")
  local schema_icon = icons.schema or ""

  -- Calculate count display (fast - just collecting, no sorting needed)
  local count_display = ""
  local filtered_objects = {}

  if schema.is_loaded then
    -- Use cached sorted objects if available, otherwise collect unsorted for count
    local all_objects = schema._sorted_objects or TreeRender.collect_schema_objects(schema)

    -- Apply filters to get filtered list and effective total
    local filters = UiFilters.get(schema)
    local effective_total
    filtered_objects, effective_total = UiFilters.apply(all_objects, filters)
    local filtered_count = #filtered_objects

    -- Get count display (shows "x/y" if filtered, or just "x" if not)
    count_display = " " .. UiFilters.get_count_display(schema, filtered_count, effective_total)
  end

  -- Schema line with icon, count, and element tracking
  cb:spans({
    { text = indent },
    { text = expand_icon .. " " .. schema_icon .. " " .. schema.name .. count_display,
      style = "SsnsSchema",
      track = {
        name = "schema_" .. schema.name,
        type = "schema",
        data = { object = schema },
        row_based = true,
      },
    },
  })

  -- If expanded, render children
  if schema.ui_state.expanded then
    if not schema.is_loaded then
      -- Schema data not loaded yet
      cb:spans({{ text = indent .. "    Loading " .. (schema.name or "schema") .. "...", style = "SsnsStatusConnecting" }})
    elseif schema._sorting then
      -- Async sort in progress - add placeholder line for spinner overlay
      -- (spinner is already running from when sort started)
      cb:line("")  -- Empty line - spinner overlays this
    elseif schema._sorted_objects then
      -- Have cached sorted objects - render them
      for _, obj in ipairs(filtered_objects) do
        TreeRender.render_object(UiTree, obj, cb, indent_level + 1)
      end
    else
      -- Need to start async sort
      -- Add placeholder line for spinner overlay (0-indexed for spinner)
      local spinner_line = cb:line_count()  -- This will be the line index after we add it
      cb:line("")  -- Empty line - spinner will overlay

      -- Start async sort with spinner - defer to next tick so buffer is written first
      vim.defer_fn(function()
        if not schema._sorting and not schema._sorted_objects then
          TreeRender.sort_schema_objects_async(schema, {
            bufnr = Buffer.bufnr,
            line = spinner_line,  -- 0-indexed line for spinner
            on_complete = function()
              -- Re-render tree when sort completes
              vim.schedule(function()
                TreeRender.render(UiTree)
              end)
            end,
          })
        end
      end, 10)  -- Small delay to ensure buffer is written
    end
  end
end

---Render an object group (TABLES, VIEWS, etc.)
---@param UiTree table The main UiTree module
---@param group BaseDbObject
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_object_group(UiTree, group, cb, indent_level)
  local UiFilters = require('nvim-ssns.ui.core.filters')
  local indent = string.rep("  ", indent_level)
  local icon = group.ui_state.expanded and "▾ " or "▸ "

  -- Get children - they should already be loaded by toggle_node if expanded
  -- Re-fetch from parent to get latest data with skip_load to avoid re-querying
  if group.ui_state.expanded and group.parent and group.parent.object_type == "database" then
    local db = group.parent
    local adapter = db:get_adapter()

    -- Update group children with latest data from database (skip_load prevents re-querying)
    if group.object_type == "tables_group" then
      group.children = db:get_tables(nil, { skip_load = true })
    elseif group.object_type == "views_group" and adapter.features.views then
      group.children = db:get_views(nil, { skip_load = true })
    elseif group.object_type == "procedures_group" and adapter.features.procedures then
      group.children = db:get_procedures(nil, { skip_load = true })
    elseif group.object_type == "functions_group" and adapter.features.functions then
      -- Special handling for FUNCTIONS group with sub-groups
      local all_functions = db:get_functions(nil, { skip_load = true })
      local scalar_functions = {}
      local table_functions = {}
      for _, func in ipairs(all_functions) do
        if func:is_table_valued() then
          table.insert(table_functions, func)
        else
          table.insert(scalar_functions, func)
        end
      end
      -- Update sub-groups
      for _, child in ipairs(group.children) do
        if child.object_type == "scalar_functions_group" then
          child.children = scalar_functions
        elseif child.object_type == "table_functions_group" then
          child.children = table_functions
        end
      end
    elseif group.object_type == "synonyms_group" and adapter.features.synonyms then
      group.children = db:get_synonyms(nil, { skip_load = true })
    end
  end

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

  -- Group line with count display and element tracking
  -- Strip any existing count from name (in case it's already there)
  local base_name = group.name:gsub("%s*%([%d/]+%)$", "")
  local count_display = UiFilters.get_count_display(group, filtered_count, total_count)
  cb:spans({
    { text = indent },
    { text = icon .. base_name .. " " .. count_display,
      style = "SsnsGroup",
      track = {
        name = "group_" .. group.object_type,
        type = group.object_type,
        data = { object = group },
        row_based = true,
      },
    },
  })

  -- If expanded, render filtered children
  if group.ui_state.expanded and #filtered_children > 0 then
    -- Sort by schema name then object name (case-insensitive)
    table.sort(filtered_children, function(a, b)
      local a_schema = (a.schema_name or ""):lower()
      local b_schema = (b.schema_name or ""):lower()
      if a_schema ~= b_schema then
        return a_schema < b_schema
      end
      return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    for _, child in ipairs(filtered_children) do
      TreeRender.render_object(UiTree, child, cb, indent_level + 1)
    end
  end
end

---Render a database object (table, view, etc.)
---@param UiTree table The main UiTree module
---@param obj BaseDbObject
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_object(UiTree, obj, cb, indent_level)
  local Config = require('nvim-ssns.config')
  local icons = Config.get_ui().icons
  local indent = string.rep("  ", indent_level)

  -- Check if this is an action or detail node
  if obj.object_type == "action" then
    -- Action nodes (SELECT, DROP, etc.)
    local action_icon = icons.action or ""
    cb:spans({
      { text = indent .. "  " },
      { text = action_icon .. " " .. obj.name, style = "SsnsAction",
        track = {
          name = "action_" .. obj.name,
          type = "action",
          data = { object = obj },
          row_based = true,
        },
      },
    })
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
    or obj.object_type == "scalar_functions_group"
    or obj.object_type == "table_functions_group"
    or obj.object_type == "synonyms_group"
    or obj.object_type == "schemas_group"
    or obj.object_type == "system_databases_group"
    or obj.object_type == "system_schemas_group"
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
  local obj_icon = TreeRender.get_object_icon(obj.object_type, icons, obj)

  -- Check if this is a schema node or object group
  local is_schema_node = obj.object_type == "schema" or obj.object_type == "schema_view"
  local is_object_group = obj.object_type == "databases_group" or
                          obj.object_type == "tables_group" or
                          obj.object_type == "views_group" or
                          obj.object_type == "procedures_group" or
                          obj.object_type == "functions_group" or
                          obj.object_type == "scalar_functions_group" or
                          obj.object_type == "table_functions_group" or
                          obj.object_type == "synonyms_group" or
                          obj.object_type == "sequences_group" or
                          obj.object_type == "system_databases_group" or
                          obj.object_type == "system_schemas_group"

  -- For groups and schemas, use name directly and add count
  -- For other objects, use get_display_name if available
  local display_name
  if is_schema_node or is_object_group then
    -- Strip any existing count from name (in case it's already there)
    local base_name = obj.name:gsub("%s*%([%d/]+%)$", "")
    display_name = base_name
    if obj:has_children() or obj._total_items then
      local UiFilters = require('nvim-ssns.ui.core.filters')
      local filters = UiFilters.get(obj)
      local all_children = obj:get_children()
      local filtered_children = UiFilters.apply(all_children, filters)
      -- Use _total_items for parent groups with nested sub-groups (e.g., FUNCTIONS)
      local total_count = obj._total_items or #all_children
      local filtered_count = obj._total_items or #filtered_children
      local count_display = UiFilters.get_count_display(obj, filtered_count, total_count)
      display_name = display_name .. " " .. count_display
    end
  else
    display_name = obj.get_display_name and obj:get_display_name() or obj.name
  end

  -- Get highlight style based on object type
  local style = TreeRender.get_object_style(obj.object_type)

  -- Object line with element tracking
  cb:spans({
    { text = indent },
    { text = expand_icon .. " " .. obj_icon .. " " .. display_name,
      style = style,
      track = {
        name = obj.object_type .. "_" .. (obj.name or ""),
        type = obj.object_type,
        data = { object = obj },
        row_based = true,
      },
    },
  })

  -- If expanded, render children
  if obj.ui_state.expanded then
    if obj.ui_state.error then
      -- Show error message
      local error_icon = icons.error or "✗"
      cb:spans({{ text = indent .. "  " .. error_icon .. " Error: " .. obj.ui_state.error, style = "SsnsStatusError" }})
    elseif obj.ui_state.loading then
      -- Show loading indicator with object name
      cb:spans({{ text = indent .. "  Loading " .. (obj.name or "objects") .. "...", style = "SsnsStatusConnecting" }})
    else
      -- Check if this is a structural group that needs alignment
      if obj.object_type == "column_group" or obj.object_type == "index_group" or
         obj.object_type == "key_group" or obj.object_type == "parameter_group" then
        -- Load the group if not loaded (this populates children)
        if not obj.is_loaded and obj.load then
          obj:load()
        end
        TreeRender.render_aligned_group(UiTree, obj, cb, indent_level + 1)
      elseif obj:has_children() then
        -- Regular children rendering (only if has children)
        local all_children = obj:get_children()

        -- Apply filtering for schema nodes or object groups
        local is_schema_node_inner = obj.object_type == "schema" or obj.object_type == "schema_view"
        local is_object_group_inner = obj.object_type == "databases_group" or
                                obj.object_type == "tables_group" or
                                obj.object_type == "views_group" or
                                obj.object_type == "procedures_group" or
                                obj.object_type == "functions_group" or
                                obj.object_type == "scalar_functions_group" or
                                obj.object_type == "table_functions_group" or
                                obj.object_type == "synonyms_group" or
                                obj.object_type == "sequences_group" or
                                obj.object_type == "system_databases_group" or
                                obj.object_type == "system_schemas_group"

        if is_schema_node_inner or is_object_group_inner then
          local UiFilters = require('nvim-ssns.ui.core.filters')
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
              TreeRender.render_database(UiTree, child, cb, indent_level + 1)
            elseif child.object_type == "schema" then
              TreeRender.render_schema(UiTree, child, cb, indent_level + 1)
            else
              TreeRender.render_object(UiTree, child, cb, indent_level + 1)
            end
          end
        else
          -- Regular rendering without filters
          for _, child in ipairs(all_children) do
            -- Delegate to specialized renderers for complex objects
            if child.object_type == "database" then
              TreeRender.render_database(UiTree, child, cb, indent_level + 1)
            elseif child.object_type == "schema" then
              TreeRender.render_schema(UiTree, child, cb, indent_level + 1)
            else
              TreeRender.render_object(UiTree, child, cb, indent_level + 1)
            end
          end
        end
      end
    end
  end
end

---Render a structural group with aligned columns
---@param UiTree table The main UiTree module
---@param group BaseDbObject
---@param cb ContentBuilder
---@param indent_level number
function TreeRender.render_aligned_group(UiTree, group, cb, indent_level)
  local indent = string.rep("  ", indent_level)
  local children = group:get_children()

  if #children == 0 then
    -- Show "(No <type>)" message for empty groups
    -- Keep plural form (Columns, Indexes, Keys, Parameters)
    local message = string.format("(No %s)", group.name)
    cb:spans({{ text = indent .. "  " .. message, style = "Comment" }})
    return
  end

  -- First pass: Calculate max widths for each field
  local max_widths = {}
  local formatted_rows = {}

  for _, child in ipairs(children) do
    local row = TreeRender.format_detail_row(child, group.object_type)
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
  local Config = require('nvim-ssns.config')
  local icons = Config.get_ui().icons

  -- Second pass: Render with aligned columns using ContentBuilder
  for i, row in ipairs(formatted_rows) do
    local parts = {}
    for idx, value in ipairs(row) do
      local width = max_widths[idx] or #value
      local padded = value .. string.rep(" ", width - #value)
      table.insert(parts, padded)
    end

    -- Get icon and style for this object type
    local child = children[i]
    local obj_icon = TreeRender.get_object_icon(child.object_type, icons, child)
    local style = TreeRender.get_object_style(child.object_type)

    -- Add icon and aligned content with element tracking
    local display_text = obj_icon .. " " .. table.concat(parts, " | ")
    cb:spans({
      { text = indent .. "  " },
      { text = display_text,
        style = style,
        track = {
          name = child.object_type .. "_" .. (child.name or ""),
          type = child.object_type,
          data = { object = child },
          row_based = true,
        },
      },
    })
    end
end

---Format a detail row for alignment
---@param obj BaseDbObject
---@param group_type string
---@return string[]?
function TreeRender.format_detail_row(obj, group_type)
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

return TreeRender
