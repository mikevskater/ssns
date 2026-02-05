---@class ObjectSearchState
---Shared state and type definitions for the object search module
local M = {}

local Spinner = require('nvim-ssns.async.spinner')

-- ============================================================================
-- Type Definitions
-- ============================================================================

---@class SearchableObject
---@field object BaseDbObject The actual database object
---@field object_type string "table"|"view"|"procedure"|"function"|"synonym"|"schema"
---@field name string Object name
---@field schema_name string? Schema name (nil for schema objects)
---@field database_name string Database name
---@field server_name string Server name
---@field definition string? Lazy loaded definition
---@field definition_loaded boolean Whether definition has been loaded
---@field metadata_text string? Concatenated column/parameter names for search
---@field metadata_loaded boolean Whether metadata has been loaded
---@field unique_id string Unique identifier "server:db:schema:type:name"

---@class MatchPosition
---@field start number 1-indexed start position in the text
---@field end_ number 1-indexed end position in the text (end_ avoids Lua keyword)
---@field text string The matched text fragment

---@class MatchDetail
---@field field string "name"|"definition"|"metadata"
---@field matched_text string The text that matched
---@field positions MatchPosition[]? Array of ALL match positions in this field

---@class SearchResult
---@field searchable SearchableObject The matched object
---@field match_type string "name"|"definition"|"metadata"|"multiple"
---@field match_details MatchDetail[] Details of all matches
---@field display_name string Pre-computed display string
---@field sort_priority number For result ordering (name=1, def=2, meta=3)

---@class ObjectSearchUIState
---@field selected_server ServerClass? Currently selected server
---@field selected_databases table<string, DbClass> Map of db_name -> DbClass
---@field all_databases_selected boolean Whether SELECT ALL is active
---@field loaded_objects SearchableObject[] Flattened list of searchable objects
---@field loading_status string "idle"|"loading"|"loading_metadata"|"ready"|"error"|"cancelled"
---@field loading_progress number 0-100 progress percentage
---@field loading_message string Current loading status message
---@field loading_detail string? Current operation detail (e.g., "tables", "views")
---@field server_loading boolean Whether server is connecting/loading databases
---@field search_ready boolean Whether search is ready (metadata preloaded)
---@field search_term string Committed search term
---@field search_term_before_edit string For ESC revert
---@field search_editing boolean Currently editing search
---@field search_names boolean Search in object names
---@field search_definitions boolean Search in definitions
---@field search_metadata boolean Search in metadata (columns/parameters)
---@field show_system boolean Show system schemas/databases
---@field case_sensitive boolean Case sensitive search
---@field use_regex boolean Use regex for search
---@field whole_word boolean Match whole words only
---@field filtered_results SearchResult[] Results after filtering
---@field selected_result_idx number Currently selected result (1-indexed)
---@field definitions_cache table<string, string> object_id -> definition cache

-- ============================================================================
-- Constants
-- ============================================================================

---System schemas to filter out when show_system is false
M.SYSTEM_SCHEMAS = {
  ["sys"] = true,
  ["INFORMATION_SCHEMA"] = true,
  ["guest"] = true,
  ["db_owner"] = true,
  ["db_accessadmin"] = true,
  ["db_securityadmin"] = true,
  ["db_ddladmin"] = true,
  ["db_backupoperator"] = true,
  ["db_datareader"] = true,
  ["db_datawriter"] = true,
  ["db_denydatareader"] = true,
  ["db_denydatawriter"] = true,
}

---System databases to filter out when show_system is false
M.SYSTEM_DATABASES = {
  ["master"] = true,
  ["model"] = true,
  ["msdb"] = true,
  ["tempdb"] = true,
}

---Chunk size for async search processing (fallback when threading unavailable)
M.SEARCH_CHUNK_SIZE = 100

-- ============================================================================
-- Module State Variables
-- ============================================================================

---@type MultiPanelState?
local multi_panel = nil

---@type number?
local search_augroup = nil

---@type string Last focused right panel ("definition" or "metadata")
local last_right_panel = "definition"

---@type CancellationToken? Active cancellation token for object loading
local loading_cancel_token = nil

---@type TextSpinner? Text spinner for loading animation
local loading_text_spinner = nil

---@type CancellationToken? Active cancellation token for search filtering
local search_cancel_token = nil

---@type boolean Whether a chunked search is in progress
local search_in_progress = false

---@type number Search progress (0-100)
local search_progress = 0

---@type number Total objects being searched (after pre-filtering)
local search_total_objects = 0

---@type number Start time of current search (for elapsed time)
local search_start_time = 0

---@type TextSpinner? Text spinner for search filtering animation
local search_text_spinner = nil

---@type string? Active thread task ID for search filtering
local search_thread_task_id = nil

---@type ObjectSearchUIState
local ui_state = {
  selected_server = nil,
  selected_databases = {},
  all_databases_selected = false,
  loaded_objects = {},
  loading_status = "idle",
  loading_progress = 0,
  loading_message = "",
  loading_detail = nil,
  server_loading = false,
  search_ready = false,
  search_term = "",
  search_term_before_edit = "",
  search_editing = false,
  -- Search target filters (what to search in)
  search_names = true,
  search_definitions = true,
  search_metadata = true,
  -- Object type filters (what types to show)
  show_tables = true,
  show_views = true,
  show_procedures = true,
  show_functions = true,
  show_synonyms = true,
  show_schemas = false,
  -- Search options
  show_system = false,
  case_sensitive = false,
  use_regex = true,
  whole_word = false,
  filtered_results = {},
  selected_result_idx = 1,
  definitions_cache = {},
  -- Cached visible object count (invalidated on filter changes)
  _visible_count_cache = nil,
  -- Cached server options (loaded async)
  _cached_saved_connections = nil,
  -- Pre-filtered objects cache (filtered by system + object type)
  -- Structure: { key: string, objects: SearchableObject[] }
  _pre_filtered_cache = nil,
  -- Serializable objects cache for threaded search
  -- Structure: { key: string, objects: table[] }
  -- Cleared when UI closes to save memory
  _serializable_cache = nil,
}

---Saved state that persists between open/close cycles
---Allows user to resume where they left off
local saved_state = nil

---Forward reference for render_settings (injected by init.lua)
---@type fun(state: MultiPanelState): ContentBuilder
local render_settings_fn = nil

-- ============================================================================
-- State Accessors
-- ============================================================================

---Get the UI state table
---@return ObjectSearchUIState
function M.get_ui_state()
  return ui_state
end

---Get the multi-panel instance
---@return MultiPanelState?
function M.get_multi_panel()
  return multi_panel
end

---Set the multi-panel instance
---@param mp MultiPanelState?
function M.set_multi_panel(mp)
  multi_panel = mp
end

---Get the search augroup ID
---@return number?
function M.get_search_augroup()
  return search_augroup
end

---Set the search augroup ID
---@param id number?
function M.set_search_augroup(id)
  search_augroup = id
end

---Get the last focused right panel
---@return string
function M.get_last_right_panel()
  return last_right_panel
end

---Set the last focused right panel
---@param panel string
function M.set_last_right_panel(panel)
  last_right_panel = panel
end

---Get the loading cancel token
---@return CancellationToken?
function M.get_loading_cancel_token()
  return loading_cancel_token
end

---Set the loading cancel token
---@param token CancellationToken?
function M.set_loading_cancel_token(token)
  loading_cancel_token = token
end

---Get the search cancel token
---@return CancellationToken?
function M.get_search_cancel_token()
  return search_cancel_token
end

---Set the search cancel token
---@param token CancellationToken?
function M.set_search_cancel_token(token)
  search_cancel_token = token
end

---Get whether search is in progress
---@return boolean
function M.get_search_in_progress()
  return search_in_progress
end

---Set whether search is in progress
---@param in_progress boolean
function M.set_search_in_progress(in_progress)
  search_in_progress = in_progress
end

---Get search progress (0-100)
---@return number
function M.get_search_progress()
  return search_progress
end

---Set search progress (0-100)
---@param progress number
function M.set_search_progress(progress)
  search_progress = progress
end

---Get total objects being searched
---@return number
function M.get_search_total_objects()
  return search_total_objects
end

---Set total objects being searched
---@param total number
function M.set_search_total_objects(total)
  search_total_objects = total
end

---Get search start time
---@return number
function M.get_search_start_time()
  return search_start_time
end

---Set search start time
---@param time number
function M.set_search_start_time(time)
  search_start_time = time
end

---Get the search thread task ID
---@return string?
function M.get_search_thread_task_id()
  return search_thread_task_id
end

---Set the search thread task ID
---@param id string?
function M.set_search_thread_task_id(id)
  search_thread_task_id = id
end

---Inject the render_settings function (called by init.lua)
---@param fn fun(state: MultiPanelState): ContentBuilder
function M.set_render_settings_fn(fn)
  render_settings_fn = fn
end

-- ============================================================================
-- Pre-Filtered & Serializable Object Caches
-- ============================================================================

-- Forward declaration for Helpers (to avoid circular dependency)
local Helpers = nil

---Lazily load Helpers module (breaks circular dependency)
---@return table
local function get_helpers()
  if not Helpers then
    Helpers = require('nvim-ssns.ui.panels.object_search.helpers')
  end
  return Helpers
end

---Generate cache key based on current filter settings
---@return string
function M.get_filter_cache_key()
  return string.format("%s|%s|%s|%s|%s|%s|%s",
    tostring(ui_state.show_system),
    tostring(ui_state.show_tables),
    tostring(ui_state.show_views),
    tostring(ui_state.show_procedures),
    tostring(ui_state.show_functions),
    tostring(ui_state.show_synonyms),
    tostring(ui_state.show_schemas)
  )
end

---Generate cache key for serializable objects (includes search target settings)
---@return string
function M.get_serializable_cache_key()
  return string.format("%s|%s|%s|%s",
    M.get_filter_cache_key(),
    tostring(ui_state.search_names),
    tostring(ui_state.search_definitions),
    tostring(ui_state.search_metadata)
  )
end

---Get pre-filtered objects (builds cache if needed)
---Returns objects already filtered by system + object type filters
---@return SearchableObject[]
function M.get_pre_filtered_objects()
  local cache_key = M.get_filter_cache_key()

  -- Return cached if valid
  if ui_state._pre_filtered_cache and ui_state._pre_filtered_cache.key == cache_key then
    return ui_state._pre_filtered_cache.objects
  end

  -- Build filtered list
  local helpers = get_helpers()
  local filtered = {}
  for _, obj in ipairs(ui_state.loaded_objects) do
    if ui_state.show_system or not helpers.is_system_object(obj) then
      if helpers.should_show_object_type(obj) then
        table.insert(filtered, obj)
      end
    end
  end

  ui_state._pre_filtered_cache = { key = cache_key, objects = filtered }
  return filtered
end

---Get serializable objects for threaded search (builds cache if needed)
---Returns pre-filtered objects converted to serializable format for thread worker
---@return table[] serializable_objects
function M.get_serializable_objects()
  local cache_key = M.get_serializable_cache_key()

  -- Return cached if valid
  if ui_state._serializable_cache and ui_state._serializable_cache.key == cache_key then
    return ui_state._serializable_cache.objects
  end

  -- Get pre-filtered objects first (uses its own cache)
  local pre_filtered = M.get_pre_filtered_objects()
  local helpers = get_helpers()

  -- Build index map for O(1) lookup: unique_id -> original index
  local idx_map = {}
  for j, loaded_obj in ipairs(ui_state.loaded_objects) do
    idx_map[loaded_obj.unique_id] = j
  end

  -- Build serializable list
  local serializable = {}
  for i, obj in ipairs(pre_filtered) do
    table.insert(serializable, {
      idx = idx_map[obj.unique_id] or i,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      display_name = helpers.build_display_name(obj),
      unique_id = obj.unique_id,
      -- Include preloaded data based on search target settings
      definition = ui_state.search_definitions and obj.definition or nil,
      metadata_text = ui_state.search_metadata and obj.metadata_text or nil,
    })
  end

  ui_state._serializable_cache = { key = cache_key, objects = serializable }
  return serializable
end

---Invalidate pre-filtered cache (call when filters or loaded_objects change)
---Also invalidates serializable cache since it depends on pre-filtered
function M.invalidate_pre_filtered_cache()
  ui_state._pre_filtered_cache = nil
  ui_state._serializable_cache = nil
  ui_state._visible_count_cache = nil
end

---Invalidate serializable cache only (call when search targets change)
function M.invalidate_serializable_cache()
  ui_state._serializable_cache = nil
end

---Clear serializable cache to free memory (call when UI closes)
function M.clear_serializable_cache()
  ui_state._serializable_cache = nil
end

-- ============================================================================
-- Spinner Functions
-- ============================================================================

---Start the text spinner animation for loading
function M.start_spinner_animation()
  if loading_text_spinner and loading_text_spinner:is_running() then
    return  -- Already running
  end

  loading_text_spinner = Spinner.create_text_spinner({
    on_tick = function()
      -- Stop if no loading activity
      local is_loading_objects = ui_state.loading_status == "loading"
      local is_loading_server = ui_state.server_loading

      if not is_loading_objects and not is_loading_server then
        if loading_text_spinner then
          loading_text_spinner:stop()
        end
        return
      end

      -- Re-render relevant panels to update spinner
      if multi_panel then
        if is_loading_objects then
          multi_panel:render_panel("results")
        end
        if is_loading_server and render_settings_fn then
          -- Re-render settings panel to animate database dropdown spinner
          local new_cb = render_settings_fn(multi_panel)
          multi_panel:update_inputs("settings", new_cb)
          multi_panel:render_panel("settings")
        end
      end
    end,
  })

  loading_text_spinner:start(100)  -- 100ms interval
end

---Stop the text spinner animation for loading
function M.stop_spinner_animation()
  if loading_text_spinner then
    loading_text_spinner:stop()
    loading_text_spinner = nil
  end
end

---Start the search spinner animation
function M.start_search_spinner()
  if search_text_spinner and search_text_spinner:is_running() then
    return  -- Already running
  end

  search_text_spinner = Spinner.create_text_spinner({
    on_tick = function()
      -- Stop if search is not in progress
      if not search_in_progress then
        if search_text_spinner then
          search_text_spinner:stop()
        end
        return
      end

      -- Re-render results panel to update spinner
      if multi_panel then
        multi_panel:render_panel("results")
      end
    end,
  })

  search_text_spinner:start(100)  -- 100ms interval
end

---Stop the search spinner animation
function M.stop_search_spinner()
  if search_text_spinner then
    search_text_spinner:stop()
    search_text_spinner = nil
  end
end

---Get formatted elapsed time for search
---@return string
function M.get_search_elapsed_time()
  if search_start_time == 0 then
    return "0.0s"
  end
  local elapsed_ms = (vim.uv.hrtime() - search_start_time) / 1000000
  return string.format("%.1fs", elapsed_ms / 1000)
end

---Get current spinner frame for loading
---@return string
function M.get_loading_spinner_frame()
  if loading_text_spinner then
    return loading_text_spinner:get_frame()
  end
  return ""
end

---Get current spinner frame for search
---@return string
function M.get_search_spinner_frame()
  if search_text_spinner then
    return search_text_spinner:get_frame()
  end
  return ""
end

-- ============================================================================
-- Panel Refresh Helper
-- ============================================================================

---Refresh UI panels (results, filters, and optionally settings)
---@param opts { settings: boolean?, all: boolean? }? Options: settings=include settings panel, all=include all panels
function M.refresh_panels(opts)
  opts = opts or {}
  if not multi_panel or not multi_panel:is_valid() then
    return
  end

  multi_panel:render_panel("results")
  multi_panel:render_panel("filters")

  if opts.settings or opts.all then
    multi_panel:render_panel("settings")
  end
end

-- ============================================================================
-- State Management Functions
-- ============================================================================

---Reset UI state to defaults
---@param clear_saved boolean? If true, also clears saved_state (full reset)
function M.reset_state(clear_saved)
  ui_state = {
    selected_server = nil,
    selected_databases = {},
    all_databases_selected = false,
    loaded_objects = {},
    loading_status = "idle",
    loading_progress = 0,
    loading_message = "",
    loading_detail = nil,
    server_loading = false,
    search_ready = false,
    search_term = "",
    search_term_before_edit = "",
    search_editing = false,
    -- Search target filters
    search_names = true,
    search_definitions = true,
    search_metadata = true,
    -- Object type filters
    show_tables = true,
    show_views = true,
    show_procedures = true,
    show_functions = true,
    show_synonyms = true,
    show_schemas = false,
    -- Search options
    show_system = false,
    case_sensitive = false,
    use_regex = true,
    whole_word = false,
    filtered_results = {},
    selected_result_idx = 1,
    definitions_cache = {},
    -- Cached visible count
    _visible_count_cache = nil,
    -- Cached saved connections (loaded async)
    _cached_saved_connections = nil,
    -- Pre-filtered and serializable caches
    _pre_filtered_cache = nil,
    _serializable_cache = nil,
  }

  if clear_saved then
    saved_state = nil
  end
end

---Save current state for later restoration
---Called when closing the panel to preserve user's work
function M.save_current_state()
  -- Only save if we have meaningful state (server selected or objects loaded)
  if not ui_state.selected_server and #ui_state.loaded_objects == 0 then
    saved_state = nil
    return
  end

  saved_state = {
    -- Server/database selection
    selected_server = ui_state.selected_server,
    selected_databases = vim.deepcopy(ui_state.selected_databases),
    all_databases_selected = ui_state.all_databases_selected,
    -- Loaded data
    loaded_objects = ui_state.loaded_objects,  -- Keep reference (don't deep copy - too expensive)
    filtered_results = ui_state.filtered_results,
    definitions_cache = ui_state.definitions_cache,
    -- Search state
    search_term = ui_state.search_term,
    selected_result_idx = ui_state.selected_result_idx,
    -- Search filters
    search_names = ui_state.search_names,
    search_definitions = ui_state.search_definitions,
    search_metadata = ui_state.search_metadata,
    -- Object type filters
    show_tables = ui_state.show_tables,
    show_views = ui_state.show_views,
    show_procedures = ui_state.show_procedures,
    show_functions = ui_state.show_functions,
    show_synonyms = ui_state.show_synonyms,
    show_schemas = ui_state.show_schemas,
    -- Search options
    show_system = ui_state.show_system,
    case_sensitive = ui_state.case_sensitive,
    use_regex = ui_state.use_regex,
    whole_word = ui_state.whole_word,
    -- Cached connections
    _cached_saved_connections = ui_state._cached_saved_connections,
  }
end

---Restore previously saved state
---@return boolean restored True if state was restored
function M.restore_saved_state()
  if not saved_state then
    return false
  end

  -- Restore all saved fields
  ui_state.selected_server = saved_state.selected_server
  ui_state.selected_databases = saved_state.selected_databases
  ui_state.all_databases_selected = saved_state.all_databases_selected
  ui_state.loaded_objects = saved_state.loaded_objects
  ui_state.filtered_results = saved_state.filtered_results
  ui_state.definitions_cache = saved_state.definitions_cache
  ui_state.search_term = saved_state.search_term
  ui_state.selected_result_idx = saved_state.selected_result_idx
  ui_state.search_names = saved_state.search_names
  ui_state.search_definitions = saved_state.search_definitions
  ui_state.search_metadata = saved_state.search_metadata
  ui_state.show_tables = saved_state.show_tables
  ui_state.show_views = saved_state.show_views
  ui_state.show_procedures = saved_state.show_procedures
  ui_state.show_functions = saved_state.show_functions
  ui_state.show_synonyms = saved_state.show_synonyms
  ui_state.show_schemas = saved_state.show_schemas
  ui_state.show_system = saved_state.show_system
  ui_state.case_sensitive = saved_state.case_sensitive
  ui_state.use_regex = saved_state.use_regex
  ui_state.whole_word = saved_state.whole_word
  ui_state._cached_saved_connections = saved_state._cached_saved_connections

  -- Update loading status based on loaded objects
  if #ui_state.loaded_objects > 0 then
    ui_state.loading_status = "complete"
    ui_state.loading_message = string.format("Loaded %d objects", #ui_state.loaded_objects)
    -- Enable search when restoring state with loaded objects
    ui_state.search_ready = true
  end

  return true
end

---Check if there is saved state available
---@return boolean
function M.has_saved_state()
  return saved_state ~= nil
end

return M
