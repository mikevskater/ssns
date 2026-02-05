---@class TreeFeatures
---Tree feature functions for SSNS (dependencies, filters, context actions)
---Extracted from ui/core/tree.lua
local TreeFeatures = {}

---Show object dependencies in a floating window
---@param obj BaseDbObject
function TreeFeatures.show_dependencies(obj)
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

  local UiFloat = require('nvim-float.window')
  local ContentBuilder = require('nvim-float.content')
  local cb = ContentBuilder.new()

  -- Show "DEPENDS ON" section
  if #depends_on > 0 then
    cb:section("This object depends on:")
    cb:blank()
    for _, dep in ipairs(depends_on) do
      cb:spans({
        { text = "  [" },
        { text = dep.schema_name, style = "sql_schema" },
        { text = "].[" },
        { text = dep.object_name, style = "sql_table" },
        { text = "] (" },
        { text = dep.object_type, style = "muted" },
        { text = ")" },
      })
    end
    cb:blank()
  end

  -- Show "DEPENDED ON BY" section
  if #depended_on_by > 0 then
    cb:section("This object is depended on by:")
    cb:blank()
    for _, dep in ipairs(depended_on_by) do
      cb:spans({
        { text = "  [" },
        { text = dep.schema_name, style = "sql_schema" },
        { text = "].[" },
        { text = dep.object_name, style = "sql_table" },
        { text = "] (" },
        { text = dep.object_type, style = "muted" },
        { text = ")" },
      })
    end
  end

  cb:blank()
  cb:spans({
    { text = "Total: ", style = "label" },
    { text = tostring(#dependencies), style = "number" },
    { text = " dependencies" },
  })

  UiFloat.create_styled(cb, {
    title = "Dependencies",
    min_width = 80,
    max_height = 30,
    footer = "q/Esc: close",
  })
end

---Open filter editor for the current group
---@param UiTree table The main UiTree module
function TreeFeatures.open_filter(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')

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
    "scalar_functions_group", "table_functions_group",
    "synonyms_group", "sequences_group", "schema", "schema_view",  -- Individual schema nodes, not schemas_group
    "system_databases_group", "system_schemas_group"
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
  local UiFilterInput = require('nvim-ssns.ui.dialogs.filter_input')
  local UiFilters = require('nvim-ssns.ui.core.filters')
  local current_filters = UiFilters.get(obj)

  UiFilterInput.show_input(obj, current_filters, function(filter_state)
    -- Apply filters
    UiFilters.set(obj, filter_state)
    -- Re-render tree
    UiTree.render()
  end)
end

---Clear filters for the current group
---@param UiTree table The main UiTree module
function TreeFeatures.clear_filter(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')

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
    "scalar_functions_group", "table_functions_group",
    "synonyms_group", "sequences_group", "schema", "schema_view",  -- Individual schema nodes, not schemas_group
    "system_databases_group", "system_schemas_group"
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
  local UiFilters = require('nvim-ssns.ui.core.filters')
  UiFilters.clear(obj)

  -- Refresh tree
  UiTree.render()

  vim.notify("SSNS: Filters cleared", vim.log.levels.INFO)
end

---Create a new query buffer using the database context from the current tree node
---@param UiTree table The main UiTree module
function TreeFeatures.new_query_from_context(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local Query = require('nvim-ssns.ui.core.query')
  local Cache = require('nvim-ssns.cache')

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

  -- Close floating tree before creating new buffer
  Buffer.close_if_float()

  -- Create buffer (USE statement is handled inside create_query_buffer)
  Query.create_query_buffer(server, database, "", "Query")
end

---Show history for the server of the current node
---@param UiTree table The main UiTree module
function TreeFeatures.show_history_from_context(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local UiHistory = require('nvim-ssns.ui.panels.history')

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  -- Close floating tree before opening history panel
  Buffer.close_if_float()

  if not obj then
    -- No object under cursor, show all history
    UiHistory.show_history()
    return
  end

  -- Get server from the hovered object's hierarchy
  local server = obj:get_server()

  if server then
    -- Show history filtered by server name
    UiHistory.show_history({ server = server.name })
  else
    -- Fallback: show all history
    UiHistory.show_history()
  end
end

---View definition (ALTER script) for the object under cursor
---Uses async loading with spinner feedback
---@param UiTree table The main UiTree module
function TreeFeatures.view_definition(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local Query = require('nvim-ssns.ui.core.query')
  local Async = require('nvim-ssns.async')

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    vim.notify("SSNS: No object under cursor", vim.log.levels.WARN)
    return
  end

  -- Skip non-definable objects (servers, databases, groups, actions)
  local skip_types = {
    server = true,
    database = true,
    schema = true,
    action = true,
    column_group = true,
    index_group = true,
    key_group = true,
    actions_group = true,
    tables_group = true,
    views_group = true,
    procedures_group = true,
    functions_group = true,
    synonyms_group = true,
  }

  if skip_types[obj.object_type] then
    vim.notify("SSNS: Cannot view definition for " .. obj.object_type, vim.log.levels.WARN)
    return
  end

  -- Check if object supports definition loading
  if not obj.get_definition and not obj.load_definition_async then
    vim.notify("SSNS: Object does not support viewing definition", vim.log.levels.WARN)
    return
  end

  -- Get server and database for later use
  local server = obj:get_server()
  local database = obj:get_database()

  -- Prefer async loading if available
  if obj.load_definition_async then
    -- Set loading state on object for UI feedback
    obj.ui_state.loading = true
    UiTree.render()

    -- Load definition asynchronously
    obj:load_definition_async({
      on_complete = function(definition, err)
        obj.ui_state.loading = false

        if err then
          vim.notify(string.format("SSNS: Failed to load definition: %s", err), vim.log.levels.ERROR)
          UiTree.render()
          return
        end

        if definition then
          Query.create_query_buffer(server, database, definition, obj.name)
        else
          vim.notify("SSNS: No definition available for " .. (obj.name or "object"), vim.log.levels.WARN)
        end
        UiTree.render()
      end,
    })
  else
    -- Fallback to sync get_definition
    local definition = obj:get_definition()
    if definition then
      Query.create_query_buffer(server, database, definition, obj.name)
    else
      vim.notify("SSNS: No definition available for " .. (obj.name or "object"), vim.log.levels.WARN)
    end
  end
end

---Build metadata lines for an object
---@param obj BaseDbObject
---@return string[] lines
local function build_metadata_lines(obj)
  local lines = {}
  table.insert(lines, "=== " .. (obj.name or "Object") .. " ===")
  table.insert(lines, "")
  table.insert(lines, "Type: " .. (obj.object_type or "unknown"))

  -- Add type-specific metadata
  if obj.object_type == "server" then
    local conn = obj.connection_config
    if conn then
      table.insert(lines, "DB Type: " .. (conn.type or "unknown"))
      if conn.server then
        table.insert(lines, "Host: " .. (conn.server.host or "unknown"))
        if conn.server.instance then
          table.insert(lines, "Instance: " .. conn.server.instance)
        end
        if conn.server.port then
          table.insert(lines, "Port: " .. conn.server.port)
        end
      end
    end
  elseif obj.object_type == "database" then
    table.insert(lines, "Database: " .. (obj.db_name or obj.name))
  elseif obj.object_type == "schema" then
    table.insert(lines, "Schema: " .. (obj.schema_name or obj.name))
  elseif obj.object_type == "table" or obj.object_type == "view" then
    table.insert(lines, "Schema: " .. (obj.schema_name or "unknown"))
    if obj.columns_loaded and obj.columns then
      table.insert(lines, "Columns: " .. #obj.columns)
      table.insert(lines, "")
      -- List column names with types
      for i, col in ipairs(obj.columns) do
        if i <= 20 then -- Limit to first 20 columns
          local col_info = col.column_name or col.name
          if col.data_type then
            col_info = col_info .. " (" .. col.data_type .. ")"
          end
          if col.is_primary_key then
            col_info = col_info .. " [PK]"
          end
          table.insert(lines, "  " .. col_info)
        elseif i == 21 then
          table.insert(lines, "  ... and " .. (#obj.columns - 20) .. " more")
        end
      end
    end
  elseif obj.object_type == "procedure" or obj.object_type == "function" then
    table.insert(lines, "Schema: " .. (obj.schema_name or "unknown"))
    if obj.parameters_loaded and obj.parameters then
      table.insert(lines, "Parameters: " .. #obj.parameters)
      if #obj.parameters > 0 then
        table.insert(lines, "")
        -- List parameters with types
        for _, param in ipairs(obj.parameters) do
          local param_info = param.parameter_name or param.name
          if param.data_type then
            param_info = param_info .. " (" .. param.data_type .. ")"
          end
          if param.direction then
            param_info = param_info .. " [" .. param.direction .. "]"
          end
          table.insert(lines, "  " .. param_info)
        end
      end
    end
  elseif obj.object_type == "column" then
    table.insert(lines, "Data Type: " .. (obj.data_type or "unknown"))
    if obj.is_nullable ~= nil then
      table.insert(lines, "Nullable: " .. (obj.is_nullable and "Yes" or "No"))
    end
    if obj.is_primary_key then
      table.insert(lines, "Primary Key: Yes")
    end
  end

  return lines
end

---View metadata for the object under cursor
---Uses async loading with spinner when columns/parameters need to be fetched
---@param UiTree table The main UiTree module
function TreeFeatures.view_metadata(UiTree)
  local Buffer = require('nvim-ssns.ui.core.buffer')
  local Float = require('nvim-float.window')
  local Spinner = require('nvim-ssns.async.spinner')

  local line_number = Buffer.get_current_line()
  local obj = UiTree.line_map[line_number]

  if not obj then
    vim.notify("SSNS: No object under cursor", vim.log.levels.WARN)
    return
  end

  -- Skip non-metadata objects
  local skip_types = {
    action = true,
    column_group = true,
    index_group = true,
    key_group = true,
    actions_group = true,
  }

  if skip_types[obj.object_type] then
    vim.notify("SSNS: Cannot view metadata for " .. obj.object_type, vim.log.levels.WARN)
    return
  end

  -- Determine if we need async loading
  local needs_async_load = false
  local async_load_fn = nil

  if (obj.object_type == "table" or obj.object_type == "view") and not obj.columns_loaded then
    if obj.load_columns_async then
      needs_async_load = true
      async_load_fn = function(on_complete)
        obj:load_columns_async({ on_complete = on_complete })
      end
    end
  elseif (obj.object_type == "procedure" or obj.object_type == "function") and not obj.parameters_loaded then
    if obj.load_parameters_async then
      needs_async_load = true
      async_load_fn = function(on_complete)
        obj:load_parameters_async({ on_complete = on_complete })
      end
    end
  end

  if needs_async_load and async_load_fn then
    -- Create float window with loading state
    local obj_name = obj.name or "Object"
    local loading_lines = {
      "=== " .. obj_name .. " ===",
      "",
      "Loading " .. obj_name .. "...",
    }

    local float_win = Float.create(loading_lines, {
      title = "Metadata: " .. obj_name,
      min_width = 50,
      modifiable = true, -- Allow updates
    })

    -- Start spinner in the float window
    local spinner_id = Spinner.start_in_buffer(float_win.bufnr, {
      text = "Loading " .. obj_name .. "...",
      line = 2, -- Line 3 (0-indexed)
      show_runtime = true,
    })

    -- Execute async load
    async_load_fn(function(result, err)
      -- Stop spinner
      Spinner.stop(spinner_id)

      if not float_win:is_valid() then
        return -- Window was closed
      end

      if err then
        local error_lines = {
          "=== " .. (obj.name or "Object") .. " ===",
          "",
          "Error loading metadata:",
          tostring(err),
        }
        float_win:update_lines(error_lines)
        return
      end

      -- Update window with loaded metadata
      local lines = build_metadata_lines(obj)
      float_win:update_lines(lines)
    end)
  else
    -- No async loading needed, show metadata immediately
    local lines = build_metadata_lines(obj)
    Float.create(lines, {
      title = "Metadata: " .. (obj.name or "Object"),
      min_width = 50,
    })
  end
end

return TreeFeatures
