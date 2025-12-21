---@class UiObjectSearch
---Main entry point for the object search module
local M = {}

-- ============================================================================
-- Module Imports
-- ============================================================================

local State = require('ssns.ui.panels.object_search.state')
local Helpers = require('ssns.ui.panels.object_search.helpers')
local Loader = require('ssns.ui.panels.object_search.loader')
local Search = require('ssns.ui.panels.object_search.search')
local Render = require('ssns.ui.panels.object_search.render')
local Input = require('ssns.ui.panels.object_search.input')
local Navigation = require('ssns.ui.panels.object_search.navigation')

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local KeymapManager = require('ssns.keymap_manager')
local Cache = require('ssns.cache')

-- ============================================================================
-- Forward Reference Wiring
-- ============================================================================

-- Wire up cross-module dependencies using setter injection
-- This avoids circular require issues

-- State needs render_settings for spinner animation
State.set_render_settings_fn(function(state)
  return Render.render_settings(state)
end)

-- Loader needs apply_search_async for auto-search after loading
Loader.set_apply_search_async_fn(function(term, callback)
  Search.apply_search_async(term, callback)
end)

-- Search needs load_definition and load_metadata_text for content search
Search.set_load_definition_fn(function(searchable)
  return Loader.load_definition(searchable)
end)
Search.set_load_metadata_text_fn(function(searchable)
  return Loader.load_metadata_text(searchable)
end)

-- Render needs load_definition for definition panel
Render.set_load_definition_fn(function(searchable)
  return Loader.load_definition(searchable)
end)

-- Input needs apply_search_async for committing searches
Input.set_apply_search_async_fn(function(term, callback)
  Search.apply_search_async(term, callback)
end)

-- Navigation needs load_definition, load_objects_for_databases, and close
Navigation.set_load_definition_fn(function(searchable)
  return Loader.load_definition(searchable)
end)
Navigation.set_load_objects_for_databases_fn(function()
  Loader.load_objects_for_databases()
end)
Navigation.set_close_fn(function()
  M.close()
end)

-- ============================================================================
-- Internal Exports for Cross-Module Access
-- ============================================================================

-- Export search function for use by other modules
M._apply_search_async = Search.apply_search_async

-- ============================================================================
-- Public API
-- ============================================================================

---Close the object search window
function M.close()
  local multi_panel = State.get_multi_panel()
  local search_augroup = State.get_search_augroup()

  -- Cancel any active loading operation
  Loader.cancel_object_loading()

  -- Cancel any active search (chunked or threaded)
  Search.cancel_search()

  -- Stop spinner animation
  State.stop_spinner_animation()

  -- Clear loading state
  State.set_loading_cancel_token(nil)

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    State.set_search_augroup(nil)
  end

  if multi_panel then
    multi_panel:close()
    State.set_multi_panel(nil)
  end

  -- Save state for next open (don't reset - preserve user's work)
  State.save_current_state()
end

---Show the object search UI
---@param options table? Options {server?: ServerClass, database?: DbClass, reset?: boolean}
function M.show(options)
  options = options or {}

  local multi_panel = State.get_multi_panel()
  local ui_state = State.get_ui_state()

  -- Close existing panel (saves state)
  if multi_panel then
    multi_panel:close()
    State.set_multi_panel(nil)
  end

  -- Check if we should restore saved state or start fresh
  local restored = false
  if not options.reset and State.has_saved_state() then
    -- Restore previous state
    State.reset_state()  -- Clear current state first
    restored = State.restore_saved_state()
  else
    -- Fresh start
    State.reset_state(true)  -- Clear saved state too
  end

  -- Get fresh reference after reset
  ui_state = State.get_ui_state()

  -- Load saved connections asynchronously (for server dropdown)
  local Connections = require('ssns.connections')
  Connections.load_async(function(connections, err)
    if not err then
      ui_state._cached_saved_connections = connections
      -- Re-render settings panel if it exists to show new server options
      vim.schedule(function()
        local mp = State.get_multi_panel()
        if mp and mp:is_valid() then
          local new_cb = Render.render_settings(mp)
          mp:update_inputs("settings", new_cb)
          mp:render_panel("settings")
        end
      end)
    end
  end)

  -- Get keymaps from config
  local km = KeymapManager.get_group("object_search")
  local common = KeymapManager.get_group("common")

  -- Create multi-panel window
  -- Layout: Top row (search + settings) | Bottom (results + metadata/definition)
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "vertical",  -- Top section vs bottom section
      children = {
        {
          -- Top row: search (left) + settings (right)
          split = "horizontal",
          ratio = 0.10,
          min_height = 4,
          children = {
            {
              name = "search",
              title = "Search",
              ratio = 0.40,
              min_height = 1,
              focusable = false,
              cursorline = false,
              on_render = Render.render_search,
            },
            {
              name = "settings",
              title = "Settings",
              ratio = 0.60,
              focusable = true,
              cursorline = false,
              on_render = function(state)
                local cb = Render.render_settings(state)
                return cb:build_lines(), cb:build_highlights()
              end,
              on_focus = function()
                local mp = State.get_multi_panel()
                if mp then
                  mp:update_panel_title("settings", "Settings ●")
                  mp:update_panel_title("results", "Results")
                  mp:update_panel_title("metadata", "Metadata")
                  mp:update_panel_title("definition", "Definition")
                  -- Position cursor on the first dropdown (server)
                  vim.schedule(function()
                    if mp and mp:is_valid() then
                      local settings_panel = mp.panels["settings"]
                      if settings_panel and settings_panel.input_manager then
                        local dropdown_order = settings_panel.input_manager.dropdown_order
                        if dropdown_order and #dropdown_order > 0 then
                          local first_dropdown_key = dropdown_order[1]
                          local dropdown = settings_panel.input_manager.dropdowns[first_dropdown_key]
                          if dropdown and settings_panel.float:is_valid() then
                            vim.api.nvim_win_set_cursor(settings_panel.float.winid, { dropdown.line, dropdown.col_start })
                          end
                        end
                      end
                    end
                  end)
                end
              end,
            },
          },
        },
        {
          -- Bottom section: (filters + results) (left) + metadata/definition (right)
          split = "horizontal",
          ratio = 0.90,
          children = {
            {
              -- Left column: filters + results
              split = "vertical",
              ratio = 0.40,
              children = {
                {
                  name = "filters",
                  title = "Filters",
                  ratio = 0.05,
                  min_height = 3,
                  focusable = true,
                  cursorline = false,
                  on_render = Render.render_filters,
                  on_focus = function()
                    local mp = State.get_multi_panel()
                    if mp then
                      mp:update_panel_title("settings", "Settings")
                      mp:update_panel_title("filters", "Filters ●")
                      mp:update_panel_title("results", "Results")
                      mp:update_panel_title("metadata", "Metadata")
                      mp:update_panel_title("definition", "Definition")
                    end
                  end,
                },
                {
                  name = "results",
                  title = "Results",
                  ratio = 0.95,
                  focusable = true,
                  cursorline = true,
                  on_render = Render.render_results,
                  on_focus = function()
                    local mp = State.get_multi_panel()
                    local us = State.get_ui_state()
                    if mp then
                      mp:update_panel_title("settings", "Settings")
                      mp:update_panel_title("filters", "Filters")
                      mp:update_panel_title("results", "Results ●")
                      -- Keep the last right panel indicator
                      local last_right_panel = State.get_last_right_panel()
                      if last_right_panel == "metadata" then
                        mp:update_panel_title("metadata", "Metadata")
                        mp:update_panel_title("definition", "Definition")
                      else
                        mp:update_panel_title("metadata", "Metadata")
                        mp:update_panel_title("definition", "Definition")
                      end
                      -- Position cursor on currently selected result (deferred to handle chunked rendering)
                      vim.schedule(function()
                        if mp and mp:is_valid() then
                          local target_line = math.max(1, us.selected_result_idx)
                          -- Re-render with cursor position to ensure it's set after any pending chunks
                          mp:render_panel("results", { cursor_row = target_line, cursor_col = 0 })
                        end
                      end)
                    end
                  end,
                },
              },
            },
            {
              -- Right column: metadata + definition
              split = "vertical",
              ratio = 0.60,
              children = {
                {
                  name = "metadata",
                  title = "Metadata",
                  footer = "Tab=Results | S-Tab=Def/Meta",
                  footer_pos = "center",
                  ratio = 0.25,
                  focusable = true,
                  cursorline = false,
                  on_render = Render.render_metadata,
                  on_focus = function()
                    State.set_last_right_panel("metadata")
                    local mp = State.get_multi_panel()
                    if mp then
                      mp:update_panel_title("settings", "Settings")
                      mp:update_panel_title("filters", "Filters")
                      mp:update_panel_title("results", "Results")
                      mp:update_panel_title("metadata", "Metadata ●")
                      mp:update_panel_title("definition", "Definition")
                    end
                  end,
                },
                {
                  name = "definition",
                  title = "Definition",
                  ratio = 0.75,
                  filetype = "sql",
                  focusable = true,
                  cursorline = false,
                  on_render = Render.render_definition,
                  on_pre_filetype = function(bufnr)
                    vim.b[bufnr].ssns_skip_semantic_highlight = true
                  end,
                  use_basic_highlighting = true,
                  on_focus = function()
                    State.set_last_right_panel("definition")
                    local mp = State.get_multi_panel()
                    if mp then
                      mp:update_panel_title("settings", "Settings")
                      mp:update_panel_title("filters", "Filters")
                      mp:update_panel_title("results", "Results")
                      mp:update_panel_title("metadata", "Metadata")
                      mp:update_panel_title("definition", "Definition ●")
                    end
                  end,
                },
              },
            },
          },
        },
      },
    },
    total_width_ratio = 0.80,
    total_height_ratio = 0.80,
    initial_focus = "settings",
    augroup_name = "SSNSObjectSearch",
    controls = {
      {
        header = "Navigation",
        keys = {
          { key = "j/k", desc = "Move up/down in results" },
          { key = "Tab", desc = "Cycle focus: results → right panels" },
          { key = "S-Tab", desc = "Cycle right panels: definition ↔ metadata" },
          { key = "/", desc = "Activate search input" },
        },
      },
      {
        header = "Panels",
        keys = {
          { key = "A-s", desc = "Focus settings panel" },
          { key = "A-*", desc = "Focus filters panel" },
          { key = "A-d", desc = "Focus database dropdown" },
        },
      },
      {
        header = "Search Options",
        keys = {
          { key = "A-c", desc = "Toggle case sensitive" },
          { key = "A-x", desc = "Toggle regex mode" },
          { key = "A-w", desc = "Toggle whole word" },
          { key = "A-S", desc = "Toggle show system objects" },
        },
      },
      {
        header = "Search In",
        keys = {
          { key = "1", desc = "Toggle search names" },
          { key = "2", desc = "Toggle search definitions" },
          { key = "3", desc = "Toggle search metadata" },
        },
      },
      {
        header = "Object Types",
        keys = {
          { key = "!", desc = "Toggle tables" },
          { key = "@", desc = "Toggle views" },
          { key = "#", desc = "Toggle procedures" },
          { key = "$", desc = "Toggle functions" },
          { key = "%", desc = "Toggle synonyms" },
          { key = "^", desc = "Toggle schemas" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "Enter/A-o", desc = "Open definition in new buffer" },
          { key = "A-e", desc = "SELECT/EXEC in new buffer" },
          { key = "A-y", desc = "Yank object name" },
          { key = "A-r", desc = "Refresh objects from database" },
          { key = "A-R", desc = "Clear saved state (full reset)" },
          { key = "A-q/Esc", desc = "Close" },
        },
      },
    },
    on_close = function()
      local search_augroup = State.get_search_augroup()
      if search_augroup then
        pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
        State.set_search_augroup(nil)
      end
      -- Save state before closing (preserve user's work)
      State.save_current_state()
      State.set_multi_panel(nil)
    end,
  })

  if not multi_panel then
    return
  end

  State.set_multi_panel(multi_panel)

  -- Render all panels
  multi_panel:render_all()

  -- Setup inputs for settings panel (enables dropdowns)
  local settings_cb = Render.render_settings(multi_panel)
  multi_panel:setup_inputs("settings", settings_cb, {
    on_dropdown_change = function(key, value)
      if key == "server" then
        -- Server changed - find or create server and connect
        local server = Cache.find_server(value)

        if not server then
          local Conns = require('ssns.connections')
          local conn = Conns.find(value)
          if conn then
            server = Cache.find_or_create_server(value, conn)
          end
        end

        if server then
          -- Reset state for new server
          ui_state.selected_databases = {}
          ui_state.all_databases_selected = false
          ui_state.loaded_objects = {}
          ui_state.filtered_results = {}

          -- Show loading state in database dropdown
          ui_state.server_loading = true
          ui_state.selected_server = server

          -- Start spinner animation for database dropdown
          State.start_spinner_animation()

          -- Update UI to show loading state immediately
          local new_cb = Render.render_settings(multi_panel)
          multi_panel:update_inputs("settings", new_cb)
          State.refresh_panels({ settings = true })

          -- Use true non-blocking RPC async (UI stays responsive)
          server:connect_and_load_async({
            on_complete = function(success, err)
              -- Stop loading state
              ui_state.server_loading = false
              State.stop_spinner_animation()

              if not success then
                vim.notify("Failed to connect to " .. value .. ": " .. (err or "Unknown error"), vim.log.levels.ERROR)
              end

              -- Refresh settings panel to show database options
              local mp = State.get_multi_panel()
              if mp and mp:is_valid() then
                local final_cb = Render.render_settings(mp)
                mp:update_inputs("settings", final_cb)
                State.refresh_panels({ settings = true })
              end
            end,
          })
        end
      end
    end,
    on_multi_dropdown_change = function(key, values)
      if key == "databases" then
        -- Databases changed - update selected databases
        ui_state.selected_databases = {}
        for _, name in ipairs(values) do
          if ui_state.selected_server then
            local db = ui_state.selected_server:find_database(name)
            if db then
              ui_state.selected_databases[name] = db
            end
          end
        end

        -- Reload objects with new database selection
        if next(ui_state.selected_databases) then
          Loader.load_objects_for_databases()
        else
          -- Clear results if no databases selected
          ui_state.loaded_objects = {}
          ui_state.filtered_results = {}
          State.refresh_panels()
        end
      elseif key == "search_options" then
        -- Update search options state from dropdown
        ui_state.case_sensitive = vim.tbl_contains(values, "case")
        ui_state.use_regex = vim.tbl_contains(values, "regex")
        ui_state.whole_word = vim.tbl_contains(values, "word")
        ui_state.show_system = vim.tbl_contains(values, "system")
        Input.apply_current_search()
        Input.sync_filter_dropdowns()  -- Show system affects object count in filters
        State.refresh_panels()
      end
    end,
  })

  -- Setup inputs for filters panel (enables dropdowns)
  local filters_cb = ContentBuilder.new()
  filters_cb:multi_dropdown("search_targets", {
    label = "Search In",
    label_width = 11,
    options = {
      { value = "names", label = "Names {1}" },
      { value = "defs", label = "Definitions {2}" },
      { value = "meta", label = "Metadata {3}" },
    },
    values = Render.get_search_targets_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 70,
  })
  filters_cb:multi_dropdown("object_types", {
    label = "Types",
    label_width = 11,
    options = {
      { value = "table", label = "T Tables {!}" },
      { value = "view", label = "V Views {@}" },
      { value = "procedure", label = "P Procs {#}" },
      { value = "function", label = "F Funcs {$}" },
      { value = "synonym", label = "S Synonyms {%}" },
      { value = "schema", label = "σ Schemas {^}" },
    },
    values = Render.get_object_types_values(),
    display_mode = "list",
    select_all_option = true,
    placeholder = "(none)",
    width = 70,
  })
  multi_panel:setup_inputs("filters", filters_cb, {
    on_multi_dropdown_change = function(key, values)
      if key == "search_targets" then
        -- Update search target state from dropdown
        ui_state.search_names = vim.tbl_contains(values, "names")
        ui_state.search_definitions = vim.tbl_contains(values, "defs")
        ui_state.search_metadata = vim.tbl_contains(values, "meta")
        Input.apply_current_search()
        State.refresh_panels()
      elseif key == "object_types" then
        -- Update object type state from dropdown
        ui_state.show_tables = vim.tbl_contains(values, "table")
        ui_state.show_views = vim.tbl_contains(values, "view")
        ui_state.show_procedures = vim.tbl_contains(values, "procedure")
        ui_state.show_functions = vim.tbl_contains(values, "function")
        ui_state.show_synonyms = vim.tbl_contains(values, "synonym")
        ui_state.show_schemas = vim.tbl_contains(values, "schema")
        Input.apply_current_search()
        State.refresh_panels()
      end
    end,
  })

  -- Position cursor on the first dropdown (server) in settings panel
  vim.schedule(function()
    local mp = State.get_multi_panel()
    if mp and mp:is_valid() then
      local settings_panel = mp.panels["settings"]
      if settings_panel and settings_panel.input_manager then
        local dropdown_order = settings_panel.input_manager.dropdown_order
        if dropdown_order and #dropdown_order > 0 then
          local first_dropdown_key = dropdown_order[1]
          local dropdown = settings_panel.input_manager.dropdowns[first_dropdown_key]
          if dropdown and settings_panel.float:is_valid() then
            vim.api.nvim_win_set_cursor(settings_panel.float.winid, { dropdown.line, dropdown.col_start })
          end
        end
      end
    end
  end)

  -- Helper functions for keymaps
  local function focus_server_dropdown()
    multi_panel:focus_field("settings", "server")
  end

  local function focus_database_dropdown()
    multi_panel:focus_field("settings", "databases")
  end

  local function focus_filters_panel()
    multi_panel:focus_panel("filters")
  end

  local function focus_settings_panel()
    multi_panel:focus_first_field("settings")
  end

  -- Custom Tab navigation: results <-> last right panel (definition/metadata)
  local function navigate_tab()
    local current_panel = multi_panel.focused_panel
    if current_panel == "results" then
      -- Jump to last focused right panel
      multi_panel:focus_panel(State.get_last_right_panel())
    elseif current_panel == "definition" or current_panel == "metadata" then
      -- Jump back to results
      multi_panel:focus_panel("results")
    else
      -- From settings/filters, jump to results
      multi_panel:focus_panel("results")
    end
  end

  -- Custom Shift+Tab navigation: cycle between definition and metadata
  local function navigate_shift_tab()
    local current_panel = multi_panel.focused_panel
    if current_panel == "definition" then
      multi_panel:focus_panel("metadata")
    elseif current_panel == "metadata" then
      multi_panel:focus_panel("definition")
    else
      -- From other panels, go to the last right panel
      multi_panel:focus_panel(State.get_last_right_panel())
    end
  end

  -- Common keymaps shared by all panels
  -- All letter keys use Alt+ modifier to preserve default Neovim controls
  local function get_common_keymaps()
    return {
      [common.close or "<A-q>"] = function() M.close() end,
      [common.cancel or "<Esc>"] = function() M.close() end,
      ["<C-c>"] = function()
        -- Cancel object loading if in progress
        if ui_state.loading_status == "loading" then
          Loader.cancel_object_loading()
        else
          M.close()
        end
      end,
      ["<Tab>"] = navigate_tab,
      ["<S-Tab>"] = navigate_shift_tab,
      ["/"] = Input.activate_search,
      ["<A-s>"] = focus_settings_panel,
      ["<A-d>"] = focus_database_dropdown,
      ["<A-*>"] = focus_filters_panel,
      ["<A-c>"] = Input.toggle_case_sensitive,
      ["<A-x>"] = Input.toggle_regex,
      ["<A-w>"] = Input.toggle_whole_word,
      ["<A-S>"] = Input.toggle_system,
      ["1"] = Input.toggle_search_names,
      ["2"] = Input.toggle_search_defs,
      ["3"] = Input.toggle_search_meta,
      ["<A-r>"] = Navigation.refresh_objects,
      ["<A-R>"] = function() M.reset(false) end,  -- Clear state without reopen
      -- Object type toggles
      ["!"] = Input.toggle_tables,
      ["@"] = Input.toggle_views,
      ["#"] = Input.toggle_procedures,
      ["$"] = Input.toggle_functions,
      ["%"] = Input.toggle_synonyms,
      ["^"] = Input.toggle_schemas,
    }
  end

  -- Setup keymaps for settings panel
  multi_panel:set_panel_keymaps("settings", get_common_keymaps())

  -- Setup keymaps for filters panel
  multi_panel:set_panel_keymaps("filters", get_common_keymaps())

  -- Setup keymaps for results panel (extends common with results-specific keymaps)
  -- Navigation (j/k, arrows) uses default Neovim movement - CursorMoved autocmd syncs selection
  local results_keymaps = get_common_keymaps()
  results_keymaps[common.confirm or "<CR>"] = Navigation.open_in_buffer
  results_keymaps["<A-o>"] = Navigation.open_in_buffer
  results_keymaps["<A-e>"] = Navigation.select_or_exec_in_buffer
  results_keymaps["<A-y>"] = Navigation.yank_object_name
  multi_panel:set_panel_keymaps("results", results_keymaps)

  -- Setup CursorMoved autocmd for results panel to sync selection with cursor
  -- This handles scrolling with mouse wheel and clicking on results
  local results_buf = multi_panel:get_panel_buffer("results")
  if results_buf and vim.api.nvim_buf_is_valid(results_buf) then
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = results_buf,
      callback = function()
        -- Get current cursor line
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

        -- Only update if cursor line is within results range
        if cursor_line >= 1 and cursor_line <= #ui_state.filtered_results then
          -- Only update if selection changed
          if ui_state.selected_result_idx ~= cursor_line then
            ui_state.selected_result_idx = cursor_line

            -- Re-render results panel to update arrow indicator
            local mp = State.get_multi_panel()
            if mp and mp:is_valid() then
              mp:render_panel("results")
              -- Also update metadata and definition panels
              mp:render_panel("metadata")
              mp:render_panel("definition")
            end
          end
        end
      end,
    })
  end

  -- Setup keymaps for metadata and definition panels
  multi_panel:set_panel_keymaps("metadata", get_common_keymaps())
  multi_panel:set_panel_keymaps("definition", get_common_keymaps())

  -- Mark initial focus (settings panel is focused initially)
  multi_panel:update_panel_title("settings", "Settings ●")

  -- Helper to refresh settings panel after state changes
  local function refresh_settings_panel()
    local new_cb = Render.render_settings(multi_panel)
    multi_panel:update_inputs("settings", new_cb)
    multi_panel:render_panel("settings")
  end

  -- Handle initial context
  if options.server then
    ui_state.selected_server = options.server

    if options.database then
      ui_state.selected_databases[options.database.db_name] = options.database
      -- Start loading objects
      vim.schedule(function()
        refresh_settings_panel()
        Loader.load_objects_for_databases()
      end)
    else
      -- Refresh settings to show server, focus on settings for database selection
      vim.schedule(function()
        refresh_settings_panel()
        multi_panel:focus_panel("settings")
      end)
    end
  else
    -- Try to detect context from current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    local db_key = vim.b[bufnr].ssns_db_key

    if db_key then
      local parts = vim.split(db_key, ":")
      if #parts >= 1 then
        local server = Cache.find_server(parts[1])
        if server then
          ui_state.selected_server = server

          if #parts >= 2 then
            local database = Cache.find_database(parts[1], parts[2])
            if database then
              ui_state.selected_databases[database.db_name] = database
              vim.schedule(function()
                refresh_settings_panel()
                Loader.load_objects_for_databases()
              end)
              return
            end
          end

          -- Have server but no database - focus settings for database selection
          vim.schedule(function()
            refresh_settings_panel()
            multi_panel:focus_panel("settings")
          end)
          return
        end
      end
    end

    -- No context - focus settings panel for server/database selection
    vim.schedule(function()
      multi_panel:focus_panel("settings")
    end)
  end
end

---Reset saved state and optionally reopen with fresh state
---@param reopen boolean? If true, close and reopen with fresh state (default: true)
function M.reset(reopen)
  if reopen == nil then reopen = true end

  local multi_panel = State.get_multi_panel()

  -- Clear saved state by doing a full reset
  State.reset_state(true)

  if reopen and multi_panel then
    -- Close and reopen with fresh state
    M.close()
    vim.schedule(function()
      M.show({ reset = true })
    end)
  elseif multi_panel then
    -- Just reset current state without reopening
    State.reset_state(true)
    -- Re-render all panels
    multi_panel:render_all()
    vim.notify("SSNS: Search state cleared", vim.log.levels.INFO)
  else
    vim.notify("SSNS: Saved search state cleared", vim.log.levels.INFO)
  end
end

---Check if object search is open
---@return boolean
function M.is_open()
  return State.get_multi_panel() ~= nil
end

-- ============================================================================
-- Expose cancel_search for external use
-- ============================================================================

M.cancel_search = Search.cancel_search

return M
