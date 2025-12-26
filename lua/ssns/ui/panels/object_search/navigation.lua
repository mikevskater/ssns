---@class ObjectSearchNavigation
---Navigation handlers for the object search module
local M = {}

local State = require('ssns.ui.panels.object_search.state')
local Cache = require('ssns.cache')

---Forward reference for load_definition (injected by init.lua)
---@type fun(searchable: SearchableObject): string?
local load_definition_fn = nil

---Forward reference for load_objects_for_databases (injected by init.lua)
---@type fun()
local load_objects_for_databases_fn = nil

---Forward reference for close (injected by init.lua)
---@type fun()
local close_fn = nil

---Inject the load_definition function (called by init.lua)
---@param fn fun(searchable: SearchableObject): string?
function M.set_load_definition_fn(fn)
  load_definition_fn = fn
end

---Inject the load_objects_for_databases function (called by init.lua)
---@param fn fun()
function M.set_load_objects_for_databases_fn(fn)
  load_objects_for_databases_fn = fn
end

---Inject the close function (called by init.lua)
---@param fn fun()
function M.set_close_fn(fn)
  close_fn = fn
end

-- ============================================================================
-- Object Actions
-- ============================================================================

---Open selected object's definition in new buffer
---Uses the same pattern as tree actions (TreeActions.execute_action "alter" action)
function M.open_in_buffer()
  local ui_state = State.get_ui_state()
  local UiQuery = require('ssns.ui.core.query')

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    return
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Use the object directly (same pattern as tree actions)
  local obj = searchable.object
  if not obj then
    vim.notify("Object not available", vim.log.levels.WARN)
    return
  end

  -- Get server and database from the object itself (like tree actions do)
  local server = obj:get_server()
  local database = obj:get_database()

  -- Close search window
  if close_fn then
    close_fn()
  end

  -- Prefer async loading if available (like tree actions "alter" action)
  if obj.load_definition_async then
    obj:load_definition_async({
      on_complete = function(definition, err)
        if err then
          vim.notify(string.format("Failed to load definition: %s", err), vim.log.levels.ERROR)
          return
        end

        if definition then
          UiQuery.create_query_buffer(server, database, definition, obj.name)
          vim.notify(string.format("Opened definition: %s.%s",
            searchable.database_name, searchable.name), vim.log.levels.INFO)
        else
          vim.notify("No definition available", vim.log.levels.WARN)
        end
      end,
    })
  elseif obj.get_definition then
    -- Fallback to sync
    local definition = obj:get_definition()
    if definition then
      UiQuery.create_query_buffer(server, database, definition, obj.name)
      vim.notify(string.format("Opened definition: %s.%s",
        searchable.database_name, searchable.name), vim.log.levels.INFO)
    else
      vim.notify("No definition available", vim.log.levels.WARN)
    end
  else
    -- Try using cached definition from searchable
    local definition = load_definition_fn and load_definition_fn(searchable) or nil
    if definition then
      UiQuery.create_query_buffer(server, database, definition, obj.name)
      vim.notify(string.format("Opened definition: %s.%s",
        searchable.database_name, searchable.name), vim.log.levels.INFO)
    else
      vim.notify("No definition available for this object", vim.log.levels.WARN)
    end
  end
end

---Yank object name to clipboard
function M.yank_object_name()
  local ui_state = State.get_ui_state()

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    return
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  local full_name
  if searchable.schema_name then
    full_name = string.format("[%s].[%s]", searchable.schema_name, searchable.name)
  else
    full_name = string.format("[%s]", searchable.name)
  end

  vim.fn.setreg("+", full_name)
  vim.fn.setreg('"', full_name)
  vim.notify("Yanked: " .. full_name, vim.log.levels.INFO)
end

---Execute SELECT or EXEC for selected object in new buffer
---Tables/Views/Functions get SELECT, Procedures get EXEC
---Uses the same pattern as tree actions (TreeActions.execute_action)
function M.select_or_exec_in_buffer()
  local ui_state = State.get_ui_state()
  local UiQuery = require('ssns.ui.core.query')

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    return
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Use the object directly (same pattern as tree actions)
  local obj = searchable.object
  if not obj then
    vim.notify("Object not available", vim.log.levels.WARN)
    return
  end

  -- Get server and database from the object itself (like tree actions do)
  local server = obj:get_server()
  local database = obj:get_database()

  -- Close search window
  if close_fn then
    close_fn()
  end

  local obj_type = searchable.object_type

  -- Generate and execute the appropriate statement (same logic as TreeActions.execute_action)
  if obj_type == "procedure" then
    -- EXEC for procedures (with parameter handling)
    if obj.generate_exec then
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
          -- Show parameter input UI
          local UiParamInput = require('ssns.ui.dialogs.param_input')
          local proc_name = (obj.schema_name and obj.schema_name .. "." or "") .. obj.procedure_name

          UiParamInput.show_input(
            proc_name,
            server and server.name or searchable.server_name,
            database and database.db_name or nil,
            input_params,
            function(values)
              -- Build EXEC statement with user-provided values
              local sql = UiQuery.build_exec_statement(obj.schema_name, obj.procedure_name, input_params, values)
              UiQuery.create_query_buffer(server, database, sql, obj.name)
            end
          )
        else
          -- No parameters, create buffer with simple EXEC
          local sql = obj:generate_exec()
          UiQuery.create_query_buffer(server, database, sql, obj.name)
        end
      end

      -- Prefer async parameter loading if available (like tree actions)
      if obj.load_parameters_async then
        obj:load_parameters_async({
          on_complete = function(parameters, err)
            if err then
              vim.notify(string.format("Failed to load parameters: %s", err), vim.log.levels.ERROR)
              -- Fallback to simple exec without parameters
              local sql = obj:generate_exec()
              UiQuery.create_query_buffer(server, database, sql, obj.name)
              return
            end
            show_exec_ui(obj.parameters)
          end,
        })
      elseif obj.load_parameters then
        -- Sync fallback
        obj:load_parameters()
        show_exec_ui(obj.parameters)
      else
        -- No parameter loading available
        show_exec_ui({})
      end
    else
      vim.notify("EXEC not available for this procedure", vim.log.levels.WARN)
    end
  else
    -- SELECT for tables, views, functions, synonyms
    if obj.generate_select then
      local sql = obj:generate_select(100)
      UiQuery.create_query_buffer(server, database, sql, obj.name)
      vim.notify(string.format("Generated SELECT for: %s.%s",
        searchable.schema_name or "", searchable.name), vim.log.levels.INFO)
    else
      vim.notify("SELECT not available for this object type", vim.log.levels.WARN)
    end
  end
end

-- ============================================================================
-- Server/Database Selection
-- ============================================================================

-- Forward declaration for show_database_picker (called from show_server_picker)
local show_database_picker

---Internal: Build and show server picker with given saved connections
---@param saved_connections ConnectionData[] Connections loaded from file
local function _show_server_picker_with_connections(saved_connections)
  local ui_state = State.get_ui_state()
  local UiFloatInteractive = require('nvim-float.float.interactive')
  local ContentBuilder = require('nvim-float.content_builder')
  local Config = require('ssns.config')

  -- Gather all servers
  local servers = {}
  local seen = {}

  -- Connected servers first
  for _, server in ipairs(Cache.servers) do
    if not seen[server.name] then
      seen[server.name] = true
      table.insert(servers, {
        name = server.name,
        server = server,
        connected = server:is_connected(),
      })
    end
  end

  -- Saved connections (passed in from async load)
  for _, conn in ipairs(saved_connections) do
    if not seen[conn.name] then
      seen[conn.name] = true
      table.insert(servers, {
        name = conn.name,
        connection_config = conn,
        connected = false,
      })
    end
  end

  -- Config connections
  local config_connections = Config.get_connections()
  for name, cfg in pairs(config_connections) do
    if not seen[name] then
      seen[name] = true
      table.insert(servers, {
        name = name,
        connection_config = cfg,
        connected = false,
      })
    end
  end

  if #servers == 0 then
    vim.notify("No servers configured", vim.log.levels.WARN)
    return
  end

  local picker_state = UiFloatInteractive.create({
    title = "Select Server",
    footer = " <CR>=Select | <Esc>=Cancel | j/k=Navigate ",
    width = 70,
    height = math.min(#servers + 4, 20),
    item_count = #servers,
    header_lines = 3,
    initial_data = { servers = servers },
    on_render = function(state)
      local cb = ContentBuilder.new()
      cb:blank()
      cb:line(" Select a server to search:")
      cb:blank()

      for i, srv in ipairs(state.data.servers) do
        local prefix = i == state.selected_idx and " ▶ " or "   "
        local status = srv.connected and "●" or "○"
        local status_style = srv.connected and "success" or "muted"

        cb:spans({
          { text = prefix, style = i == state.selected_idx and "emphasis" or "muted" },
          { text = status .. " ", style = status_style },
          { text = srv.name, style = "server" },
        })
      end

      return cb:build_lines(), cb:build_highlights()
    end,
    on_select = function(state)
      local selected = state.data.servers[state.selected_idx]
      UiFloatInteractive.close(state)

      -- Find or create server
      local server = selected.server
      if not server then
        server = Cache.find_server(selected.name)
        if not server and selected.connection_config then
          server = Cache.find_or_create_server(selected.name, selected.connection_config)
        end
      end

      if not server then
        vim.notify("Failed to create server connection", vim.log.levels.ERROR)
        return
      end

      -- Set up state for new server
      ui_state.selected_server = server
      ui_state.selected_databases = {}
      ui_state.all_databases_selected = false
      ui_state.loaded_objects = {}
      ui_state.filtered_results = {}

      -- Connect and load asynchronously if needed
      if not server:is_connected() or not server.is_loaded then
        vim.notify("Connecting to " .. selected.name .. "...", vim.log.levels.INFO)

        -- Use true non-blocking RPC async (UI stays responsive)
        server:connect_and_load_async({
          on_complete = function(success, err)
            if not success then
              vim.notify("Failed to connect: " .. (err or "Unknown"), vim.log.levels.ERROR)
              return
            end

            -- Auto-show database picker after successful connect
            vim.schedule(function()
              show_database_picker()
            end)
          end,
        })
      else
        -- Already connected and loaded - show database picker directly
        vim.schedule(function()
          show_database_picker()
        end)
      end
    end,
  })
end

---Show server picker (loads connections async then shows picker)
function M.show_server_picker()
  local Connections = require('ssns.connections')

  -- Load connections asynchronously, then show picker
  Connections.load_async(function(connections, err)
    local saved_connections = err and {} or connections
    vim.schedule(function()
      _show_server_picker_with_connections(saved_connections)
    end)
  end)
end

---Show database multi-picker
show_database_picker = function()
  local ui_state = State.get_ui_state()

  if not ui_state.selected_server then
    vim.notify("Select a server first", vim.log.levels.WARN)
    return
  end

  local server = ui_state.selected_server
  local UiFloatInteractive = require('nvim-float.float.interactive')
  local ContentBuilder = require('nvim-float.content_builder')

  ---Helper to create the picker once databases are loaded
  local function create_picker()
    local databases = server:get_databases({ skip_load = true }) or {}

    if #databases == 0 then
      vim.notify("No databases found on server", vim.log.levels.WARN)
      return
    end

    -- Initialize selection state
    local selection = {}
    for name, _ in pairs(ui_state.selected_databases) do
      selection[name] = true
    end

    local all_selected = ui_state.all_databases_selected

    local picker_state = UiFloatInteractive.create({
      title = "Select Databases",
      footer = " <Space>=Toggle | <CR>=Confirm | a=All | <Esc>=Cancel ",
      width = 70,
      height = math.min(#databases + 6, 25),
      item_count = #databases + 1,  -- +1 for SELECT ALL
      header_lines = 3,
      initial_data = {
        databases = databases,
        selection = selection,
        all_selected = all_selected,
      },
      on_render = function(state)
        local cb = ContentBuilder.new()
        cb:blank()
        cb:line(" Select databases to search:")
        cb:blank()

        -- SELECT ALL option
        local all_prefix = state.selected_idx == 1 and " ▶ " or "   "
        local all_check = state.data.all_selected and "[x]" or "[ ]"
        cb:spans({
          { text = all_prefix, style = state.selected_idx == 1 and "emphasis" or "muted" },
          { text = all_check .. " ", style = state.data.all_selected and "success" or "muted" },
          { text = "SELECT ALL", style = "strong" },
        })

        -- Individual databases (no blank line to maintain cursor alignment)
        for i, db in ipairs(state.data.databases) do
          local prefix = state.selected_idx == i + 1 and " ▶ " or "   "
          local check = (state.data.selection[db.db_name] or state.data.all_selected) and "[x]" or "[ ]"
          local style = (state.data.selection[db.db_name] or state.data.all_selected) and "success" or "muted"

          cb:spans({
            { text = prefix, style = state.selected_idx == i + 1 and "emphasis" or "muted" },
            { text = check .. " ", style = style },
            { text = db.db_name, style = "sql_database" },
          })
        end

        return cb:build_lines(), cb:build_highlights()
      end,
      on_select = function(state)
        -- Confirm selection
        UiFloatInteractive.close(state)

        ui_state.all_databases_selected = state.data.all_selected
        ui_state.selected_databases = {}

        if state.data.all_selected then
          for _, db in ipairs(state.data.databases) do
            ui_state.selected_databases[db.db_name] = db
          end
        else
          for _, db in ipairs(state.data.databases) do
            if state.data.selection[db.db_name] then
              ui_state.selected_databases[db.db_name] = db
            end
          end
        end

        -- Start loading objects
        vim.schedule(function()
          if load_objects_for_databases_fn then
            load_objects_for_databases_fn()
          end
        end)
      end,
      custom_keymaps = {
        ["<Space>"] = function(state)
          if state.selected_idx == 1 then
            -- Toggle all
            state.data.all_selected = not state.data.all_selected
            if state.data.all_selected then
              state.data.selection = {}
            end
          else
            -- Toggle individual
            local db = state.data.databases[state.selected_idx - 1]
            if db then
              state.data.selection[db.db_name] = not state.data.selection[db.db_name]
              state.data.all_selected = false
            end
          end
          UiFloatInteractive.render(state)
        end,
        ["<A-a>"] = function(state)
          state.data.all_selected = not state.data.all_selected
          if state.data.all_selected then
            state.data.selection = {}
          end
          UiFloatInteractive.render(state)
        end,
      },
    })
  end

  -- Load databases asynchronously if needed, then show picker
  if not server.databases or #server.databases == 0 then
    vim.notify("Loading databases...", vim.log.levels.INFO)
    server:load_async({
      on_complete = function(success, err)
        if not success then
          vim.notify("Failed to load databases: " .. (err or "Unknown"), vim.log.levels.ERROR)
          return
        end
        vim.schedule(create_picker)
      end,
    })
  else
    -- Already loaded - show picker directly
    create_picker()
  end
end

-- Export show_database_picker
M.show_database_picker = show_database_picker

---Refresh objects (reload from database)
function M.refresh_objects()
  local ui_state = State.get_ui_state()

  if not ui_state.selected_server then
    vim.notify("Select a server first", vim.log.levels.WARN)
    return
  end

  -- Clear caches
  ui_state.definitions_cache = {}
  ui_state.loaded_objects = {}
  ui_state.filtered_results = {}

  -- Reload
  if load_objects_for_databases_fn then
    load_objects_for_databases_fn()
  end
end

return M
