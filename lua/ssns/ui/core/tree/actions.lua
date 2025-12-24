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

  -- Determine if this object needs async loading when expanded
  -- Objects with load_async method should use async loading to avoid UI freeze
  local needs_async_load = not was_expanded and not obj.is_loaded and obj.load_async

  -- Toggle expansion - skip sync loading if we'll handle it async
  obj:toggle_expand({ skip_load = needs_async_load })

  -- Special handling for object groups: Load data when expanding
  if obj.ui_state.expanded and obj._is_ephemeral and obj.parent and obj.parent.object_type == "database" then
    local db = obj.parent
    local adapter = db:get_adapter()

    -- Ensure schemas are loaded first (for schema-based servers)
    if adapter.features.schemas then
      db:_ensure_schemas_loaded()
    end

    -- Determine async load function based on object type
    -- Use RPC async methods (non-blocking) for responsive UI
    local async_fn = nil

    if obj.object_type == "tables_group" and adapter.features.schemas then
      async_fn = function(on_complete) db:load_tables_async({ on_complete = on_complete }) end
    elseif obj.object_type == "views_group" and adapter.features.views and adapter.features.schemas then
      async_fn = function(on_complete) db:load_views_async({ on_complete = on_complete }) end
    elseif obj.object_type == "procedures_group" and adapter.features.procedures and adapter.features.schemas then
      async_fn = function(on_complete) db:load_procedures_async({ on_complete = on_complete }) end
    elseif obj.object_type == "functions_group" and adapter.features.functions and adapter.features.schemas then
      async_fn = function(on_complete) db:load_functions_async({ on_complete = on_complete }) end
    elseif obj.object_type == "synonyms_group" and adapter.features.synonyms and adapter.features.schemas then
      async_fn = function(on_complete) db:load_synonyms_async({ on_complete = on_complete }) end
    elseif obj.object_type == "schemas_group" and adapter.features.schemas then
      -- Schemas are typically fast to load, use sync for simplicity
      async_fn = nil  -- Will fall through to sync below
    end

    -- Execute async or sync load
    if async_fn then
      local Buffer = require('ssns.ui.core.buffer')
      local Config = require('ssns.config')
      local Spinner = require('ssns.async.spinner')
      local smart_positioning = Config.get_ui().smart_cursor_positioning

      -- Set loading state on the group object
      obj.ui_state.loading = true
      UiTree.render()

      -- Keep cursor on the expanded group while loading
      local col = smart_positioning and Buffer.get_name_column(line_number) or 0
      Buffer.set_cursor(line_number, col)

      -- Start animated spinner on the loading line (line after group header)
      -- line_number is 1-indexed, spinner uses 0-indexed, loading indicator is on next line
      local loading_line = line_number  -- Convert: (line_number + 1) - 1 = line_number for 0-indexed next line

      -- Calculate indentation to match tree structure
      -- Groups are rendered at indent_level, children at indent_level + 1
      -- Each indent level is 2 spaces, plus "  " prefix for the loading indicator
      local indent_level = Buffer.get_indent_level(line_number) or 0
      local indent = string.rep("  ", indent_level + 1) .. "  "

      local spinner_id = Spinner.start_in_buffer(Buffer.bufnr, {
        text = indent .. "Loading " .. (obj.name or "objects") .. "...",
        style = Config.get().async and Config.get().async.spinner_style or "braille",
        show_runtime = Config.get().async and Config.get().async.show_runtime ~= false,
        line = loading_line,
        hl_group = "Comment",
      })

      -- Force display update
      vim.cmd('redraw')

      async_fn(function(result, err)
        -- Stop the animated spinner
        Spinner.stop(spinner_id)

        obj.ui_state.loading = false

        if err then
          obj.ui_state.error = tostring(err)
          vim.notify(string.format("SSNS: Failed to load %s: %s", obj.object_type, err), vim.log.levels.ERROR)
        end

        -- Render with on_complete callback to defer cursor positioning until after
        -- all lines are written to the buffer (handles chunked rendering)
        UiTree.render({
          on_complete = function()
            -- Now position cursor on first child after render completes
            if obj:has_children() then
              local child_line = line_number + 1
              local child_col = smart_positioning and Buffer.get_name_column(child_line) or 0
              Buffer.set_cursor(child_line, child_col)
              if smart_positioning then
                Buffer.last_indent_info = {
                  line = child_line,
                  indent_level = Buffer.get_indent_level(child_line),
                  column = child_col,
                }
              end
            else
              -- No children loaded (error case or empty), stay on group
              local group_col = smart_positioning and Buffer.get_name_column(line_number) or 0
              Buffer.set_cursor(line_number, group_col)
              if smart_positioning then
                Buffer.last_indent_info = {
                  line = line_number,
                  indent_level = Buffer.get_indent_level(line_number),
                  column = group_col,
                }
              end
            end
          end,
        })
      end)

      -- Return early - cursor positioning is handled in the callback
      return
    elseif obj.object_type == "schemas_group" and adapter.features.schemas then
      -- Schemas are typically fast to load, use sync for simplicity
      db:get_schemas()
    end
  end

  -- Don't auto-load databases on expansion - groups will trigger loading when needed
  local should_load = obj.ui_state.expanded and not obj.is_loaded and obj.load and obj.object_type ~= "database"
  if should_load then
    TreeActions.load_node_async(UiTree, obj, line_number)
  else
    -- Check if smart cursor positioning is enabled
    local Config = require('ssns.config')
    local smart_positioning = Config.get_ui().smart_cursor_positioning

    -- Re-render tree with on_complete callback to defer cursor positioning
    -- until after all lines are written (handles chunked rendering for large trees)
    UiTree.render({
      on_complete = function()
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
      end,
    })
  end
end

---Load a node asynchronously with cancellation support
---@param UiTree table The main UiTree module
---@param obj BaseDbObject
---@param line_number number
function TreeActions.load_node_async(UiTree, obj, line_number)
  local Buffer = require('ssns.ui.core.buffer')
  local Config = require('ssns.config')
  local Async = require('ssns.async')
  local Spinner = require('ssns.async.spinner')
  local smart_positioning = Config.get_ui().smart_cursor_positioning

  -- Cancel any existing load operation for this object
  if obj._cancel_load then
    obj._cancel_load()
    obj._cancel_load = nil
  end

  -- Set loading state
  obj.ui_state.loading = true
  obj.ui_state.error = nil

  -- Render with loading indicator
  UiTree.render()
  local col = smart_positioning and Buffer.get_name_column(line_number) or 0
  Buffer.set_cursor(line_number, col)

  -- Start animated spinner on the loading line (line after the node header)
  -- line_number is 1-indexed, spinner uses 0-indexed, loading indicator is on next line
  local loading_line = line_number  -- Convert: (line_number + 1) - 1 = line_number for 0-indexed next line

  -- Calculate indentation to match tree structure
  -- The node is at indent_level, children are at indent_level + 1
  -- Each indent level is 2 spaces, plus "    " prefix for server/db loading indicator
  local indent_level = Buffer.get_indent_level(line_number) or 0
  local indent = string.rep("  ", indent_level + 1) .. "    "

  local spinner_id = Spinner.start_in_buffer(Buffer.bufnr, {
    text = indent .. "Loading " .. (obj.name or "node") .. "...",
    style = Config.get().async and Config.get().async.spinner_style or "braille",
    show_runtime = Config.get().async and Config.get().async.show_runtime ~= false,
    line = loading_line,
    hl_group = "Comment",
  })

  -- Force display update before RPC call
  vim.cmd('redraw')

  -- Common completion handler for both async paths
  local function handle_load_complete(success, err)
    -- Stop the animated spinner
    Spinner.stop(spinner_id)

    -- Clear loading state and cancel function
    obj.ui_state.loading = false
    obj._cancel_load = nil

    -- Handle cancellation
    if err and (tostring(err):match("cancelled") or tostring(err):match("Cancelled")) then
      -- Silently handle cancellation - don't show error
      UiTree.render()
      return
    end

    -- Handle errors
    if err then
      obj.ui_state.error = tostring(err)
      vim.notify(string.format("SSNS: Failed to load %s: %s", obj.name, err), vim.log.levels.ERROR)
      UiTree.render()
      return
    end

    -- Check if load failed
    if not success then
      local error_msg = obj.error_message or "Unknown error"
      obj.ui_state.error = error_msg
      vim.notify(string.format("SSNS: Failed to load %s: %s", obj.name, error_msg), vim.log.levels.ERROR)
    end

    -- Re-render tree with results or error
    -- Defer cursor positioning until after render completes (handles chunked rendering)
    UiTree.render({
      on_complete = function()
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
          local current_col = smart_positioning and Buffer.get_name_column(line_number) or 0
          Buffer.set_cursor(line_number, current_col)
          -- Update indent tracking
          if smart_positioning then
            Buffer.last_indent_info = {
              line = line_number,
              indent_level = Buffer.get_indent_level(line_number),
              column = current_col,
            }
          end
        end
      end,
    })
  end

  -- Check if object supports true async RPC (ServerClass)
  if obj.load_async then
    -- Use true non-blocking RPC async - UI stays responsive
    local callback_id = obj:load_async({
      timeout_ms = 60000, -- 60 seconds for metadata loads
      on_complete = handle_load_complete,
    })

    -- Store cancel function for external cancellation
    obj._cancel_load = function()
      local AsyncRPC = require('ssns.async.rpc')
      AsyncRPC.cancel(callback_id)
      Spinner.stop(spinner_id)
      obj.ui_state.loading = false
      obj._cancel_load = nil
      UiTree.render()
    end

    return -- Early return - completion handled by callback
  end

  -- Fallback: Use Async.run() for objects without true async (still blocks during RPC)
  -- Create cancellation token
  local cancel_token = Async.create_cancel_token()

  -- Store cancel function on object for external cancellation
  obj._cancel_load = function()
    cancel_token:cancel("Cancelled by user")
    Spinner.stop(spinner_id)
  end

  -- Load asynchronously using Executor (wraps blocking call)
  Async.run(function(ctx)
    -- Check cancellation before starting
    if ctx.is_cancelled() then
      return nil, "cancelled"
    end

    -- Execute the load
    local success, result = pcall(function()
      return obj:load()
    end)

    -- Check cancellation after load
    if ctx.is_cancelled() then
      return nil, "cancelled"
    end

    return { success = success, result = result }
  end, {
    name = "Load " .. (obj.name or "node"),
    cancel_token = cancel_token,
    timeout_ms = 60000, -- 60 seconds for metadata loads
    on_complete = function(load_result, err)
      -- Extract success/error from the wrapped result
      if err then
        handle_load_complete(false, err)
        return
      end

      local pcall_success = load_result and load_result.success
      local load_return = load_result and load_result.result

      -- Check if pcall failed (threw error)
      if not pcall_success then
        handle_load_complete(false, tostring(load_return))
        return
      end

      -- Check if load() returned false (failed without throwing)
      if load_return == false then
        handle_load_complete(false, nil)
        return
      end

      -- Success
      handle_load_complete(true, nil)
    end,
  })
end

---Cancel loading for a specific node
---@param obj BaseDbObject The object to cancel loading for
---@return boolean cancelled True if a load was cancelled
function TreeActions.cancel_node_load(obj)
  if obj and obj._cancel_load then
    obj._cancel_load()
    obj._cancel_load = nil
    obj.ui_state.loading = false
    return true
  end
  return false
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
      -- Helper function to show param UI and create exec statement
      local function show_exec_ui(parameters)
        -- Filter to only input parameters (IN or INOUT)
        local input_params = {}
        for _, param in ipairs(parameters or {}) do
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

      -- Prefer async parameter loading if available
      if parent.load_parameters_async then
        -- Set loading state for UI feedback
        parent.ui_state.loading = true
        UiTree.render()

        parent:load_parameters_async({
          on_complete = function(parameters, err)
            parent.ui_state.loading = false
            UiTree.render()

            if err then
              vim.notify(string.format("Failed to load parameters: %s", err), vim.log.levels.ERROR)
              -- Fallback to simple exec without parameters
              local sql = parent:generate_exec()
              Query.create_query_buffer(server, database, sql, parent.name)
              return
            end

            show_exec_ui(parent.parameters)
          end,
        })
      elseif parent.load_parameters then
        -- Sync fallback
        parent:load_parameters()
        show_exec_ui(parent.parameters)
      else
        -- No parameter loading available, use empty params
        show_exec_ui({})
      end
    end
  elseif action.action_type == "alter" then
    -- Show definition (ALTER displays the object definition)
    -- Prefer async loading if available
    if parent.load_definition_async then
      -- Set loading state for UI feedback
      parent.ui_state.loading = true
      UiTree.render()

      parent:load_definition_async({
        on_complete = function(definition, err)
          parent.ui_state.loading = false
          UiTree.render()

          if err then
            vim.notify(string.format("Failed to load definition: %s", err), vim.log.levels.ERROR)
            return
          end

          if definition then
            Query.create_query_buffer(server, database, definition, parent.name)
          else
            vim.notify("No definition available", vim.log.levels.WARN)
          end
        end,
      })
    elseif parent.get_definition then
      -- Fallback to sync
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
      -- Defer cursor positioning until after render completes
      UiTree.render({
        on_complete = function()
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
        end,
      })
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
    -- Use async toggle with callback for rendering
    obj:toggle_connection(function(success, err)
      if err then
        vim.notify(string.format("Connection failed: %s", err), vim.log.levels.ERROR)
      end

      -- Re-render tree after connection state changes
      -- Defer cursor positioning until after render completes
      UiTree.render({
        on_complete = function()
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
        end,
      })
    end)
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

  -- Check if this server has a saved connection (async)
  Connections.find_async(obj.name, function(conn, _)
    if not conn then
      -- Offer to save the connection first
      vim.notify(string.format("'%s' is not saved. Use :SSNSAddServer to save it first.", obj.name), vim.log.levels.WARN)
      return
    end

    -- Toggle favorite (async)
    Connections.toggle_favorite_async(obj.name, function(success, new_state, _)
      if success then
        local status = new_state and "added to" or "removed from"
        vim.notify(string.format("'%s' %s favorites", obj.name, status), vim.log.levels.INFO)

        -- Re-render tree to show updated star icon
        -- Defer cursor positioning until after render completes
        UiTree.render({
          on_complete = function()
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
          end,
        })
      end
    end)
  end)
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
