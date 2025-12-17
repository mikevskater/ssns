---@class TreeActions
---Tree action functions for SSNS (toggle, load, execute)
---Extracted from ui/core/tree.lua
local TreeActions = {}

---Toggle node expansion at current cursor
---@param UiTree table The main UiTree module
function TreeActions.toggle_node(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Handle "+ Add Server" action
  if obj.object_type == "add_server_action" then
    local AddServerUI = require('ssns.ui.dialogs.add_server')
    AddServerUI.open()
    return
  end

  -- Handle action nodes
  if obj.object_type == "action" then
    TreeActions.execute_action(UiTree, obj)
    return
  end

  -- Check if we're expanding or collapsing
  local was_expanded = obj.ui_state.expanded

  -- Toggle expansion
  obj:toggle_expand()

  -- Special handling for object groups: Load data when expanding
  if obj.ui_state.expanded and obj._is_ephemeral and obj.parent and obj.parent.object_type == "database" then
    local db = obj.parent
    local adapter = db:get_adapter()

    -- Ensure schemas are loaded first (for schema-based servers)
    if adapter.features.schemas then
      db:_ensure_schemas_loaded()
    end

    -- Load the appropriate object type using BULK loading for all schemas
    -- This is different from completion which may use lazy loading
    if obj.object_type == "tables_group" then
      if adapter.features.schemas then
        db:load_all_tables_bulk()  -- Force bulk load all schemas for tree view
      else
        db:get_tables()  -- Non-schema servers load directly
      end
    elseif obj.object_type == "views_group" and adapter.features.views then
      if adapter.features.schemas then
        db:load_all_views_bulk()  -- Force bulk load all schemas for tree view
      else
        db:get_views()  -- Non-schema servers load directly
      end
    elseif obj.object_type == "procedures_group" and adapter.features.procedures then
      if adapter.features.schemas then
        db:load_all_procedures_bulk()  -- Force bulk load all schemas for tree view
      else
        db:get_procedures()  -- Non-schema servers load directly
      end
    elseif obj.object_type == "functions_group" and adapter.features.functions then
      if adapter.features.schemas then
        db:load_all_functions_bulk()  -- Force bulk load all schemas for tree view
      else
        db:get_functions()  -- Non-schema servers load directly
      end
    elseif obj.object_type == "synonyms_group" and adapter.features.synonyms then
      if adapter.features.schemas then
        db:load_all_synonyms_bulk()  -- Force bulk load all schemas for tree view
      else
        db:get_synonyms()  -- Non-schema servers load directly
      end
    elseif obj.object_type == "schemas_group" and adapter.features.schemas then
      db:get_schemas()  -- Load schema names only
    end
  end

  -- Don't auto-load databases on expansion - groups will trigger loading when needed
  local should_load = obj.ui_state.expanded and not obj.is_loaded and obj.load and obj.object_type ~= "database"
  if should_load then
    TreeActions.load_node_async(UiTree, obj, line_number)
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
---@param UiTree table The main UiTree module
---@param obj BaseDbObject
---@param line_number number
function TreeActions.load_node_async(UiTree, obj, line_number)
  local Buffer = require('ssns.ui.core.buffer')
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
---@param UiTree table The main UiTree module
---@param action BaseDbObject
function TreeActions.execute_action(UiTree, action)
  local Query = require('ssns.ui.core.query')
  local UiBuffer = require('ssns.ui.core.buffer')
  local parent = action.parent


  -- Navigate up past groups to find actual parent object
  while parent and (parent.object_type == "column_group" or parent.object_type == "index_group" or parent.object_type == "key_group" or parent.object_type == "actions_group") do
    parent = parent.parent
  end

  if not parent then
    vim.notify("SSNS: Cannot find parent object for action", vim.log.levels.WARN)
    return
  end

  -- Close floating tree for actions that create new buffers/windows
  -- (except "goto" which navigates within the tree)
  if action.action_type ~= "goto" then
    UiBuffer.close_if_float()
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
        local UiParamInput = require('ssns.ui.dialogs.param_input')
        local proc_name = (parent.schema_name and parent.schema_name .. "." or "") .. parent.procedure_name

        UiParamInput.show_input(
          proc_name,
          server.name,
          database and database.db_name or nil,
          input_params,
          function(values)
            -- Build EXEC statement with user-provided values
            local UiQuery = require('ssns.ui.core.query')
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
    local TreeFeatures = require('ssns.ui.core.tree.features')
    TreeFeatures.show_dependencies(obj)
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
        local TreeNavigation = require('ssns.ui.core.tree.navigation')
        TreeNavigation.navigate_to_object(UiTree, base_object)
      else
        vim.notify(string.format("Cannot navigate: %s", error_msg or "Unknown error"), vim.log.levels.WARN)
      end
    end
  end
end

---Refresh node at current cursor
---@param UiTree table The main UiTree module
function TreeActions.refresh_node(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
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
---@param UiTree table The main UiTree module
function TreeActions.refresh_all(UiTree)
  local Cache = require('ssns').get_cache()
  Cache.refresh_all()
  vim.notify("Refreshed all servers", vim.log.levels.INFO)

  -- Re-render tree
  UiTree.render()
end

---Toggle connection for server/database at current cursor
---@param UiTree table The main UiTree module
function TreeActions.toggle_connection(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
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

---Toggle favorite status for server at current cursor
---@param UiTree table The main UiTree module
function TreeActions.toggle_favorite(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
  local Connections = require('ssns.connections')
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning
  local line_number = Buffer.get_current_line()

  -- Get object at current line
  local obj = UiTree.line_map[line_number]
  if not obj then
    return
  end

  -- Only allow on servers
  if obj.object_type ~= "server" then
    vim.notify("Can only toggle favorite on servers", vim.log.levels.WARN)
    return
  end

  -- Check if this server has a saved connection
  local conn = Connections.find(obj.name)
  if not conn then
    -- Offer to save the connection first
    vim.notify(string.format("'%s' is not saved. Use :SSNSAddServer to save it first.", obj.name), vim.log.levels.WARN)
    return
  end

  -- Toggle favorite
  local success, new_state = Connections.toggle_favorite(obj.name)

  if success then
    local status = new_state and "added to" or "removed from"
    vim.notify(string.format("'%s' %s favorites", obj.name, status), vim.log.levels.INFO)

    -- Re-render tree to show updated star icon
    UiTree.render()

    -- Restore cursor position with smart column
    local col = smart_positioning and Buffer.get_name_column(line_number) or 0
    Buffer.set_cursor(line_number, col)
    if smart_positioning then
      Buffer.last_indent_info = {
        line = line_number,
        indent_level = Buffer.get_indent_level(line_number),
        column = col,
      }
    end
  end
end

---Set lualine color for current server or database
---@param UiTree table The main UiTree module
function TreeActions.set_lualine_color(UiTree)
  local Buffer = require('ssns.ui.core.buffer')
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
    -- For servers, use server name from connection_config
    local conn_config = obj.connection_config

    if conn_config and conn_config.type == "sqlite" then
      -- For SQLite, use the database path (file path)
      local server_info = conn_config.server or {}
      if server_info.database then
        -- Normalize backslashes to forward slashes for consistency
        name = server_info.database:gsub("\\", "/")
      else
        name = ":memory:"
      end
    elseif conn_config and conn_config.server then
      -- Build server name: host[\instance]
      local server_info = conn_config.server
      name = server_info.host
      if server_info.instance then
        name = name .. "\\" .. server_info.instance
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

---Handle mouse click on tree
---@param UiTree table The main UiTree module
---@param double_click boolean? Whether this is a double-click
function TreeActions.handle_mouse_click(UiTree, double_click)
  local Buffer = require('ssns.ui.core.buffer')

  -- Verify tree is open
  if not Buffer.is_open() then
    return
  end

  -- Get actual mouse click position
  local mouse = vim.fn.getmousepos()

  -- Verify click was in the tree window
  if mouse.winid ~= Buffer.winid then
    return
  end

  local line_num = mouse.line
  local obj = UiTree.line_map[line_num]

  if not obj then
    return
  end

  -- Move cursor to clicked line
  local Config = require('ssns.config')
  local smart_positioning = Config.get_ui().smart_cursor_positioning
  local col = smart_positioning and Buffer.get_name_column(line_num) or 0
  Buffer.set_cursor(line_num, col)

  -- Update indent tracking for smart positioning
  if smart_positioning then
    Buffer.last_indent_info = {
      line = line_num,
      indent_level = Buffer.get_indent_level(line_num),
      column = col,
    }
  end

  -- On double-click, toggle expand/collapse or execute action
  if double_click then
    -- Handle action nodes - execute them
    if obj.object_type == "action" then
      TreeActions.execute_action(UiTree, obj)
      return
    end

    -- Handle "+ Add Server" action
    if obj.object_type == "add_server_action" then
      local AddServerUI = require('ssns.ui.dialogs.add_server')
      AddServerUI.open()
      return
    end

    -- Otherwise toggle expand/collapse
    TreeActions.toggle_node(UiTree)
    return
  end

  -- On single-click, check if clicked on expand icon to toggle
  -- Get line content
  local lines = vim.api.nvim_buf_get_lines(Buffer.bufnr, line_num - 1, line_num, false)
  if not lines or not lines[1] then
    return
  end

  local line = lines[1]
  local click_col = mouse.column

  -- Check if object is expandable
  local has_children = obj.object_type == "server"
    or obj.object_type == "database"
    or obj.object_type == "schema"
    or obj.object_type == "table"
    or obj.object_type == "view"
    or obj.object_type == "procedure"
    or obj.object_type == "function"
    or (obj.object_type and obj.object_type:match("_group$"))
    or (obj.has_children and obj:has_children())

  if has_children then
    -- Find expand icon position (after leading spaces)
    local indent_spaces = line:match("^(%s*)")
    local indent_len = indent_spaces and #indent_spaces or 0

    -- Expand icon is typically at indent_len + 1 to indent_len + 4 (accounting for UTF-8)
    -- Icons like ▸ or ▾ are 3 bytes in UTF-8
    if click_col >= indent_len + 1 and click_col <= indent_len + 4 then
      TreeActions.toggle_node(UiTree)
    end
  end
end

---Handle double-click on tree (expand/collapse)
---@param UiTree table The main UiTree module
function TreeActions.handle_double_click(UiTree)
  TreeActions.handle_mouse_click(UiTree, true)
end

return TreeActions
