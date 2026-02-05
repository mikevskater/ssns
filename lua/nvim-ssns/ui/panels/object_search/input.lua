---@class ObjectSearchInput
---Search input mode handling for the object search module
local M = {}

local State = require('nvim-ssns.ui.panels.object_search.state')
local Render = require('nvim-ssns.ui.panels.object_search.render')
local KeymapManager = require('nvim-ssns.keymap_manager')

---Forward reference for apply_search_async (injected by init.lua)
---@type fun(pattern: string, callback: fun()?)?
local apply_search_async_fn = nil

---Inject the apply_search_async function (called by init.lua)
---@param fn fun(pattern: string, callback: fun()?)
function M.set_apply_search_async_fn(fn)
  apply_search_async_fn = fn
end

-- ============================================================================
-- Search Exit Functions
-- ============================================================================

---Finalize search exit
function M.finalize_search_exit()
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()
  local search_augroup = State.get_search_augroup()

  ui_state.search_editing = false

  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    vim.api.nvim_buf_set_option(search_buf, 'modifiable', false)
  end

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    State.set_search_augroup(nil)
  end

  if multi_panel then
    multi_panel:render_all()
  end

  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() then
      multi_panel:focus_panel("results")
    end
  end)
end

---Cancel search (ESC)
---Reverts to previous search term WITHOUT triggering a new search.
---Any running thread continues to completion (results still valid from before edit).
function M.cancel_search()
  local ui_state = State.get_ui_state()
  ui_state.search_term = ui_state.search_term_before_edit
  -- NOTE: Do NOT trigger search here - let any running thread continue.
  -- The current results are still valid (they match the reverted term).
  vim.cmd('stopinsert')
end

---Commit search (Enter)
---Reads from buffer and triggers a new search.
function M.commit_search()
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local new_term = (lines[1] or ""):gsub("^%s+", "")

    -- Only trigger search if term actually changed
    if new_term ~= ui_state.search_term then
      ui_state.search_term = new_term
      -- Trigger the search (will use threaded version when available)
      if apply_search_async_fn then
        apply_search_async_fn(new_term)
      end
    end
  end
  vim.cmd('stopinsert')
end

-- ============================================================================
-- Search Application
-- ============================================================================

---Helper to apply search from current search term or buffer
function M.apply_current_search()
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  -- Invalidate visible count cache since filters may have changed
  Render.invalidate_visible_count_cache()

  -- Only read from buffer if we're actively editing the search
  if ui_state.search_editing then
    local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
    if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
      local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
      local text = (lines[1] or ""):gsub("^%s+", "")
      if apply_search_async_fn then
        apply_search_async_fn(text)
      end
      return
    end
  end
  -- Use committed search term (async handles rendering)
  if apply_search_async_fn then
    apply_search_async_fn(ui_state.search_term)
  end
end

-- ============================================================================
-- Dropdown Sync Functions
-- ============================================================================

---Sync filter dropdown values with current ui_state
---Call this after changing filter state via hotkeys to update the dropdowns
function M.sync_filter_dropdowns()
  local multi_panel = State.get_multi_panel()
  if not multi_panel then return end

  local filters_panel = multi_panel.panels["filters"]
  if not filters_panel or not filters_panel.input_manager then return end

  local input_manager = filters_panel.input_manager

  -- Sync search_targets dropdown
  input_manager:set_multi_dropdown_values("search_targets", Render.get_search_targets_values())

  -- Sync object_types dropdown
  input_manager:set_multi_dropdown_values("object_types", Render.get_object_types_values())
end

---Sync settings dropdown values with current ui_state
---Call this after changing settings state via hotkeys to update the dropdowns
function M.sync_settings_dropdowns()
  local multi_panel = State.get_multi_panel()
  if not multi_panel then return end

  local settings_panel = multi_panel.panels["settings"]
  if not settings_panel or not settings_panel.input_manager then return end

  local input_manager = settings_panel.input_manager

  -- Sync search_options dropdown
  input_manager:set_multi_dropdown_values("search_options", Render.get_search_options_values())
end

-- ============================================================================
-- Toggle Functions - Search Settings
-- ============================================================================

---Toggle case sensitive search
function M.toggle_case_sensitive()
  local ui_state = State.get_ui_state()

  ui_state.case_sensitive = not ui_state.case_sensitive
  M.apply_current_search()
  M.sync_settings_dropdowns()
  State.refresh_panels()
  vim.notify("Case sensitive: " .. (ui_state.case_sensitive and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle regex search
function M.toggle_regex()
  local ui_state = State.get_ui_state()

  ui_state.use_regex = not ui_state.use_regex
  M.apply_current_search()
  M.sync_settings_dropdowns()
  State.refresh_panels()
  vim.notify("Regex: " .. (ui_state.use_regex and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle whole word search
function M.toggle_whole_word()
  local ui_state = State.get_ui_state()

  ui_state.whole_word = not ui_state.whole_word
  M.apply_current_search()
  M.sync_settings_dropdowns()
  State.refresh_panels()
  vim.notify("Whole word: " .. (ui_state.whole_word and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle search in names
function M.toggle_search_names()
  local ui_state = State.get_ui_state()

  ui_state.search_names = not ui_state.search_names
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels({ settings = true })
  vim.notify("Search names: " .. (ui_state.search_names and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle search in definitions
function M.toggle_search_defs()
  local ui_state = State.get_ui_state()

  ui_state.search_definitions = not ui_state.search_definitions
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels({ settings = true })
  vim.notify("Search definitions: " .. (ui_state.search_definitions and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle search in metadata
function M.toggle_search_meta()
  local ui_state = State.get_ui_state()

  ui_state.search_metadata = not ui_state.search_metadata
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels({ settings = true })
  vim.notify("Search metadata: " .. (ui_state.search_metadata and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show system objects
function M.toggle_system()
  local ui_state = State.get_ui_state()

  ui_state.show_system = not ui_state.show_system
  M.apply_current_search()
  M.sync_settings_dropdowns()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show system: " .. (ui_state.show_system and "ON" or "OFF"), vim.log.levels.INFO)
end

-- ============================================================================
-- Toggle Functions - Object Type Filters
-- ============================================================================

---Toggle show tables
function M.toggle_tables()
  local ui_state = State.get_ui_state()

  ui_state.show_tables = not ui_state.show_tables
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show tables: " .. (ui_state.show_tables and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show views
function M.toggle_views()
  local ui_state = State.get_ui_state()

  ui_state.show_views = not ui_state.show_views
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show views: " .. (ui_state.show_views and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show procedures
function M.toggle_procedures()
  local ui_state = State.get_ui_state()

  ui_state.show_procedures = not ui_state.show_procedures
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show procedures: " .. (ui_state.show_procedures and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show functions
function M.toggle_functions()
  local ui_state = State.get_ui_state()

  ui_state.show_functions = not ui_state.show_functions
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show functions: " .. (ui_state.show_functions and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show synonyms
function M.toggle_synonyms()
  local ui_state = State.get_ui_state()

  ui_state.show_synonyms = not ui_state.show_synonyms
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show synonyms: " .. (ui_state.show_synonyms and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle show schemas
function M.toggle_schemas()
  local ui_state = State.get_ui_state()

  ui_state.show_schemas = not ui_state.show_schemas
  M.apply_current_search()
  M.sync_filter_dropdowns()
  State.refresh_panels()
  vim.notify("Show schemas: " .. (ui_state.show_schemas and "ON" or "OFF"), vim.log.levels.INFO)
end

-- ============================================================================
-- Search Autocmds
-- ============================================================================

---Setup search autocmds
function M.setup_search_autocmds()
  local multi_panel = State.get_multi_panel()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  local search_augroup = State.get_search_augroup()
  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
  end

  search_augroup = vim.api.nvim_create_augroup("SSNSObjectSearch", { clear = true })
  State.set_search_augroup(search_augroup)

  -- NOTE: Live filtering disabled for threaded search
  -- With vim.uv.new_thread(), threads can't be killed instantly (cooperative cancellation),
  -- so live filtering would spawn many threads that keep running. Instead, we use a
  -- "commit on Enter" model where search only triggers on <CR>.
  -- TextChanged autocmd intentionally removed - search triggers via commit_search()

  -- Handle insert mode exit
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = search_augroup,
    buffer = search_buf,
    once = true,
    callback = function()
      M.finalize_search_exit()
    end,
  })

  -- Setup keymaps
  KeymapManager.set(search_buf, 'i', '<Esc>', M.cancel_search, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<Tab>', M.commit_search, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<CR>', M.commit_search, { nowait = true })

  -- Search settings toggles (consistent with normal mode keymaps)
  KeymapManager.set(search_buf, 'i', '<A-c>', M.toggle_case_sensitive, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-x>', M.toggle_regex, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-w>', M.toggle_whole_word, { nowait = true })

  -- Search context toggles
  KeymapManager.set(search_buf, 'i', '<A-1>', M.toggle_search_names, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-2>', M.toggle_search_defs, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-3>', M.toggle_search_meta, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-S>', M.toggle_system, { nowait = true })

  -- Object type toggles (Alt+Shift+number)
  KeymapManager.set(search_buf, 'i', '<A-!>', M.toggle_tables, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-@>', M.toggle_views, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-#>', M.toggle_procedures, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-$>', M.toggle_functions, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-%>', M.toggle_synonyms, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-^>', M.toggle_schemas, { nowait = true })

  KeymapManager.setup_auto_restore(search_buf)
end

-- ============================================================================
-- Search Activation
-- ============================================================================

---Activate search mode
function M.activate_search()
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  if not multi_panel then return end

  -- Don't allow search activation while loading/preloading
  if not ui_state.search_ready then
    vim.notify("Please wait - loading metadata for search...", vim.log.levels.INFO)
    return
  end

  ui_state.search_term_before_edit = ui_state.search_term
  ui_state.search_editing = true

  local search_buf = multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  vim.api.nvim_buf_set_option(search_buf, 'modifiable', true)

  -- Disable autocompletion
  vim.b[search_buf].cmp_enabled = false
  vim.b[search_buf].blink_cmp_enable = false
  vim.b[search_buf].completion = false

  local initial_text = ui_state.search_term ~= "" and (" " .. ui_state.search_term) or " "
  vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, {initial_text})

  local search_win = multi_panel:get_panel_window("search")
  if search_win and vim.api.nvim_win_is_valid(search_win) then
    vim.api.nvim_set_current_win(search_win)
    vim.api.nvim_win_set_cursor(search_win, {1, #initial_text})
    vim.cmd('startinsert!')
  end

  M.setup_search_autocmds()
end

return M
