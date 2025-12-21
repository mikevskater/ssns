---@class UiObjectSearch
---Database object search UI with 4-panel floating window layout
---Search through tables, views, procedures, functions, synonyms across multiple databases
local UiObjectSearch = {}

local UiFloat = require('ssns.ui.core.float')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')
local UiQuery = require('ssns.ui.core.query')
local ContentBuilder = require('ssns.ui.core.content_builder')
local Cancellation = require('ssns.async.cancellation')
local Spinner = require('ssns.async.spinner')
local Thread = require('ssns.async.thread')

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

---@class MatchDetail
---@field field string "name"|"definition"|"metadata"
---@field matched_text string The text that matched

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
-- Module State
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

-- NOTE: search_debounce_timer removed - live filtering disabled for threaded search
-- Search now triggers only on <CR> (commit on Enter model)

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

-- Chunk size for async search processing (fallback when threading unavailable)
local SEARCH_CHUNK_SIZE = 100

-- Forward declaration for render_settings (used in spinner animation)
local render_settings

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
  search_ready = false,  -- Whether metadata is preloaded and search is enabled
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
  show_schemas = true,
  -- Search options
  show_system = false,
  case_sensitive = false,
  use_regex = false,
  whole_word = false,
  filtered_results = {},
  selected_result_idx = 1,
  definitions_cache = {},
  -- Cached visible object count (invalidated on filter changes)
  _visible_count_cache = nil,
  -- Cached server options (loaded async)
  _cached_saved_connections = nil,
}

-- Saved state that persists between open/close cycles
-- Allows user to resume where they left off
local saved_state = nil

---Start the text spinner animation
local function start_spinner_animation()
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
        if is_loading_server then
          -- Re-render settings panel to animate database dropdown spinner
          local new_cb = render_settings(multi_panel)
          multi_panel:update_inputs("settings", new_cb)
          multi_panel:render_panel("settings")
        end
      end
    end,
  })

  loading_text_spinner:start(100)  -- 100ms interval
end

---Stop the text spinner animation
local function stop_spinner_animation()
  if loading_text_spinner then
    loading_text_spinner:stop()
    loading_text_spinner = nil
  end
end

---Start the search spinner animation
local function start_search_spinner()
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
local function stop_search_spinner()
  if search_text_spinner then
    search_text_spinner:stop()
    search_text_spinner = nil
  end
end

---Get formatted elapsed time for search
---@return string
local function get_search_elapsed_time()
  if search_start_time == 0 then
    return "0.0s"
  end
  local elapsed_ms = (vim.uv.hrtime() - search_start_time) / 1000000
  return string.format("%.1fs", elapsed_ms / 1000)
end

---System schemas to filter out when show_system is false
local SYSTEM_SCHEMAS = {
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
local SYSTEM_DATABASES = {
  ["master"] = true,
  ["model"] = true,
  ["msdb"] = true,
  ["tempdb"] = true,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Check if a searchable object is a system object
---@param searchable SearchableObject
---@return boolean
local function is_system_object(searchable)
  -- Check if this is a schema object with a system schema name
  if searchable.object_type == "schema" and searchable.name and SYSTEM_SCHEMAS[searchable.name] then
    return true
  end
  -- Check if object belongs to a system schema
  if searchable.schema_name and SYSTEM_SCHEMAS[searchable.schema_name] then
    return true
  end
  -- Check if database is a system database
  if searchable.database_name and SYSTEM_DATABASES[searchable.database_name] then
    return true
  end
  return false
end

---Reset UI state to defaults
---@param clear_saved boolean? If true, also clears saved_state (full reset)
local function reset_state(clear_saved)
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
    show_schemas = true,
    -- Search options
    show_system = false,
    case_sensitive = false,
    use_regex = false,
    whole_word = false,
    filtered_results = {},
    selected_result_idx = 1,
    definitions_cache = {},
    -- Cached saved connections (loaded async)
    _cached_saved_connections = nil,
  }

  if clear_saved then
    saved_state = nil
  end
end

---Save current state for later restoration
---Called when closing the panel to preserve user's work
local function save_current_state()
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
local function restore_saved_state()
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
  end

  return true
end

---Get object type icon
---@param object_type string
---@return string icon
local function get_object_icon(object_type)
  local icons = {
    table = "T",
    view = "V",
    procedure = "P",
    ["function"] = "F",
    synonym = "S",
    schema = "σ",
  }
  return icons[object_type] or "?"
end

---Generate unique ID for an object
---@param server_name string
---@param database_name string
---@param schema_name string?
---@param object_type string
---@param name string
---@return string
local function generate_unique_id(server_name, database_name, schema_name, object_type, name)
  return string.format("%s:%s:%s:%s:%s",
    server_name,
    database_name,
    schema_name or "",
    object_type,
    name
  )
end

---Build display name for an object
---@param searchable SearchableObject
---@return string
local function build_display_name(searchable)
  if searchable.schema_name then
    return string.format("[%s].[%s]", searchable.schema_name, searchable.name)
  else
    return string.format("[%s]", searchable.name)
  end
end

---Check if an object should be shown based on its object type filter
---@param searchable SearchableObject
---@return boolean
local function should_show_object_type(searchable)
  local obj_type = searchable.object_type
  if obj_type == "table" then return ui_state.show_tables
  elseif obj_type == "view" then return ui_state.show_views
  elseif obj_type == "procedure" then return ui_state.show_procedures
  elseif obj_type == "function" then return ui_state.show_functions
  elseif obj_type == "synonym" then return ui_state.show_synonyms
  elseif obj_type == "schema" then return ui_state.show_schemas
  end
  return true  -- Show unknown types by default
end

---Check if character is a word character
---@param char string
---@return boolean
local function is_word_char(char)
  if not char or char == "" then return false end
  return char:match("[%w_]") ~= nil
end

---Check if match is a whole word
---@param text string
---@param match_start number
---@param match_end number
---@return boolean
local function is_whole_word_match(text, match_start, match_end)
  if match_start > 1 then
    local char_before = text:sub(match_start - 1, match_start - 1)
    if is_word_char(char_before) then
      return false
    end
  end
  if match_end < #text then
    local char_after = text:sub(match_end + 1, match_end + 1)
    if is_word_char(char_after) then
      return false
    end
  end
  return true
end

-- ============================================================================
-- Object Loading Functions
-- ============================================================================

---Create a SearchableObject from a database object
---@param obj BaseDbObject
---@param object_type string
---@param database DbClass
---@param server ServerClass
---@param parent_schema SchemaClass? Optional parent schema for non-schema objects
---@return SearchableObject
local function create_searchable(obj, object_type, database, server, parent_schema)
  -- For schema objects, schema_name should be nil (they don't belong to another schema)
  -- For other objects, use the parent schema name
  local schema_name = nil
  if object_type ~= "schema" then
    if parent_schema then
      schema_name = parent_schema.name
    elseif obj.schema_name then
      schema_name = obj.schema_name
    elseif obj.parent and obj.parent.object_type == "schema" then
      schema_name = obj.parent.name
    end
  end

  local searchable = {
    object = obj,
    object_type = object_type,
    name = obj.name,
    schema_name = schema_name,
    database_name = database.db_name,
    server_name = server.name,
    definition = nil,
    definition_loaded = false,
    metadata_text = nil,
    metadata_loaded = false,
    unique_id = generate_unique_id(server.name, database.db_name, schema_name, object_type, obj.name),
  }

  return searchable
end

---Flatten all objects from a database into searchable list
---@param database DbClass
---@param server ServerClass
---@return SearchableObject[]
local function flatten_database_objects(database, server)
  local searchables = {}

  -- Check if this is a schema-based database (SQL Server, PostgreSQL)
  local schemas = database:get_schemas({ skip_load = true })

  if schemas and #schemas > 0 then
    -- Schema-based database
    for _, schema in ipairs(schemas) do
      -- Add schema itself as searchable (pass nil for parent_schema since schemas don't have parent schemas)
      table.insert(searchables, create_searchable(schema, "schema", database, server, nil))

      -- Add tables (pass schema as parent)
      local tables = schema:get_tables({ skip_load = true })
      if tables then
        for _, tbl in ipairs(tables) do
          table.insert(searchables, create_searchable(tbl, "table", database, server, schema))
        end
      end

      -- Add views (pass schema as parent)
      local views = schema:get_views({ skip_load = true })
      if views then
        for _, view in ipairs(views) do
          table.insert(searchables, create_searchable(view, "view", database, server, schema))
        end
      end

      -- Add procedures (pass schema as parent)
      local procedures = schema:get_procedures({ skip_load = true })
      if procedures then
        for _, proc in ipairs(procedures) do
          table.insert(searchables, create_searchable(proc, "procedure", database, server, schema))
        end
      end

      -- Add functions (pass schema as parent)
      local functions = schema:get_functions({ skip_load = true })
      if functions then
        for _, func in ipairs(functions) do
          table.insert(searchables, create_searchable(func, "function", database, server, schema))
        end
      end

      -- Add synonyms (pass schema as parent)
      local synonyms = schema:get_synonyms({ skip_load = true })
      if synonyms then
        for _, syn in ipairs(synonyms) do
          table.insert(searchables, create_searchable(syn, "synonym", database, server, schema))
        end
      end
    end
  else
    -- Non-schema database (MySQL, SQLite) - no parent schema
    local tables = database:get_tables({ skip_load = true })
    if tables then
      for _, tbl in ipairs(tables) do
        table.insert(searchables, create_searchable(tbl, "table", database, server, nil))
      end
    end

    local views = database:get_views({ skip_load = true })
    if views then
      for _, view in ipairs(views) do
        table.insert(searchables, create_searchable(view, "view", database, server, nil))
      end
    end

    local procedures = database:get_procedures({ skip_load = true })
    if procedures then
      for _, proc in ipairs(procedures) do
        table.insert(searchables, create_searchable(proc, "procedure", database, server, nil))
      end
    end

    local functions = database:get_functions({ skip_load = true })
    if functions then
      for _, func in ipairs(functions) do
        table.insert(searchables, create_searchable(func, "function", database, server, nil))
      end
    end
  end

  return searchables
end

---Load all objects for selected databases
---@param callback function? Callback when complete
---Cancel any active object loading operation
local function cancel_object_loading()
  if loading_cancel_token then
    loading_cancel_token:cancel("User cancelled")
  end
end

---Discover and load databases referenced by cross-database synonyms
---This enables synonym resolution to work for objects in other databases
---@param callback fun()? Called when loading is complete
local function load_synonym_referenced_databases_async(callback)
  local objects = ui_state.loaded_objects
  local server = ui_state.selected_server

  if not server then
    if callback then callback() end
    return
  end

  -- Collect unique cross-database references from synonyms
  local referenced_dbs = {}  -- db_name -> true
  local already_loaded = {}  -- db_name -> true (already in selected_databases)

  for db_name, _ in pairs(ui_state.selected_databases) do
    already_loaded[db_name] = true
  end

  for _, searchable in ipairs(objects) do
    if searchable.object_type == "synonym" and searchable.object then
      local syn = searchable.object
      if syn.parse_base_object_name and syn.base_object_name then
        local parts = syn:parse_base_object_name()
        -- Check if this is a cross-database reference (not linked server)
        if parts.database and not parts.server then
          local db_name = parts.database
          if not already_loaded[db_name] and not referenced_dbs[db_name] then
            referenced_dbs[db_name] = true
          end
        end
      end
    end
  end

  -- Count references
  local ref_count = 0
  for _ in pairs(referenced_dbs) do
    ref_count = ref_count + 1
  end

  if ref_count == 0 then
    -- No cross-database references, continue
    if callback then callback() end
    return
  end

  -- Update loading status
  ui_state.loading_message = string.format("Loading %d referenced databases...", ref_count)
  if multi_panel then
    multi_panel:render_panel("results")
  end

  -- Find and load referenced databases
  local databases = server:get_databases() or {}
  local dbs_to_load = {}

  for _, db in ipairs(databases) do
    if referenced_dbs[db.db_name] then
      table.insert(dbs_to_load, db)
    end
  end

  if #dbs_to_load == 0 then
    -- Referenced databases not found on server
    if callback then callback() end
    return
  end

  -- Load databases sequentially
  local db_idx = 1
  local cancel_token = loading_cancel_token

  local function load_next_ref_db()
    if cancel_token and cancel_token.is_cancelled then
      if callback then callback() end
      return
    end

    if db_idx > #dbs_to_load then
      if callback then callback() end
      return
    end

    local db = dbs_to_load[db_idx]
    ui_state.loading_message = string.format("Loading referenced: %s (%d/%d)",
      db.db_name, db_idx, #dbs_to_load)

    if multi_panel then
      multi_panel:render_panel("results")
    end

    -- Load the database's full structure (schemas, tables, views, procedures, functions)
    -- This enables synonym resolution to find target objects
    -- We need the full async chain, not just load_async()
    local function load_ref_db_chain()
      local chain_ops = {
        function(next) db:load_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_tables_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_views_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_procedures_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_functions_async({ on_complete = function() next() end, on_error = function() next() end }) end,
      }

      local op_idx = 1
      local function run_next_op()
        if cancel_token and cancel_token.is_cancelled then
          -- Add this database to selected_databases for metadata loading
          ui_state.selected_databases[db.db_name] = db

          -- Flatten objects from this database and add to loaded_objects
          local db_objects = flatten_database_objects(db, server)
          for _, obj in ipairs(db_objects) do
            table.insert(ui_state.loaded_objects, obj)
          end

          db_idx = db_idx + 1
          vim.schedule(load_next_ref_db)
          return
        end

        if op_idx > #chain_ops then
          -- All operations complete for this database
          -- Add this database to selected_databases for metadata loading
          ui_state.selected_databases[db.db_name] = db

          -- Flatten objects from this database and add to loaded_objects
          local db_objects = flatten_database_objects(db, server)
          for _, obj in ipairs(db_objects) do
            table.insert(ui_state.loaded_objects, obj)
          end

          db_idx = db_idx + 1
          vim.schedule(load_next_ref_db)
          return
        end

        chain_ops[op_idx](function()
          op_idx = op_idx + 1
          vim.schedule(run_next_op)
        end)
      end

      run_next_op()
    end

    load_ref_db_chain()
  end

  load_next_ref_db()
end

---Preload metadata (columns/parameters) and definitions for all objects asynchronously
---Uses bulk loading per database for efficiency (single query per database)
---@param callback fun()? Called when preloading is complete
local function preload_metadata_async(callback)
  local objects = ui_state.loaded_objects
  local total = #objects

  if total == 0 then
    ui_state.search_ready = true
    ui_state.loading_status = "ready"
    ui_state.loading_message = "Ready to search"
    if callback then callback() end
    return
  end

  -- Update loading state
  ui_state.loading_status = "loading_metadata"
  ui_state.loading_progress = 0
  ui_state.loading_message = "Preloading metadata for search..."
  ui_state.search_ready = false

  -- Keep spinner running
  start_spinner_animation()

  if multi_panel then
    multi_panel:render_panel("results")
  end

  -- Get list of databases to load metadata for
  local databases = {}
  for _, db in pairs(ui_state.selected_databases) do
    table.insert(databases, db)
  end

  local total_dbs = #databases
  local completed_dbs = 0
  local all_metadata = {}  -- "db:schema.object" -> metadata text
  local all_definitions = {}  -- "db:schema.object" -> definition text
  local cancel_token = loading_cancel_token

  ---Apply loaded metadata/definitions to searchable objects
  ---Since bulk loaders now populate actual objects, we derive from objects directly
  ---IMPORTANT: Only use pre-loaded data (check *_loaded flags), never trigger sync loads
  local function apply_to_objects()
    for _, searchable in ipairs(objects) do
      local obj = searchable.object

      -- Derive metadata from actual object (ONLY if pre-loaded by bulk loader)
      -- Do NOT call get_columns()/get_parameters() as they trigger sync loads
      if obj and not searchable.metadata_loaded then
        local parts = {}

        -- For tables and views: use pre-loaded columns (direct access, no getter)
        if (searchable.object_type == "table" or searchable.object_type == "view") then
          if obj.columns_loaded and obj.columns then
            for _, col in ipairs(obj.columns) do
              table.insert(parts, col.name or col.column_name)
              if col.data_type then
                table.insert(parts, col.data_type)
              end
            end
          end
        end

        -- For procedures and functions: use pre-loaded parameters (direct access)
        if (searchable.object_type == "procedure" or searchable.object_type == "function") then
          if obj.parameters_loaded and obj.parameters then
            for _, param in ipairs(obj.parameters) do
              table.insert(parts, param.name or param.parameter_name)
              if param.data_type then
                table.insert(parts, param.data_type)
              end
            end
          end
        end

        -- For functions (TVFs): also use pre-loaded columns (direct access)
        if searchable.object_type == "function" then
          if obj.columns_loaded and obj.columns then
            for _, col in ipairs(obj.columns) do
              table.insert(parts, col.name or col.column_name)
              if col.data_type then
                table.insert(parts, col.data_type)
              end
            end
          end
        end

        searchable.metadata_text = table.concat(parts, " ")
        searchable.metadata_loaded = true
      end

      -- Derive definition from actual object (ONLY if pre-loaded by bulk loader)
      -- Do NOT call get_definition() as it triggers sync load
      if obj and not searchable.definition_loaded then
        if obj.definition_loaded and obj.definition then
          searchable.definition = obj.definition
          searchable.definition_loaded = true
          ui_state.definitions_cache[searchable.unique_id] = obj.definition
        end
        -- Note: Do NOT set searchable.definition_loaded = true if no definition found
        -- This allows load_definition() to try again later
      end
    end

    -- Done
    stop_spinner_animation()
    ui_state.loading_status = "ready"
    ui_state.loading_message = string.format("Ready - %d objects loaded", total)
    ui_state.search_ready = true

    if multi_panel then
      multi_panel:render_all()
    end

    if callback then callback() end
  end

  ---Called when a database's metadata/definitions are loaded
  local function on_db_complete()
    completed_dbs = completed_dbs + 1
    ui_state.loading_progress = math.floor((completed_dbs / total_dbs) * 100)
    ui_state.loading_message = string.format("Loading metadata... %d/%d databases", completed_dbs, total_dbs)

    if multi_panel then
      multi_panel:render_panel("results")
    end

    if completed_dbs >= total_dbs then
      -- All databases loaded, apply to objects
      apply_to_objects()
    end
  end

  ---Load metadata and definitions for a single database (sequentially)
  local function load_database(db, db_callback)
    if cancel_token and cancel_token.is_cancelled then
      db_callback()
      return
    end

    -- Step 1: Load all metadata (columns/parameters) in bulk
    local function load_metadata(next_step)
      if not db.load_all_metadata_bulk_async then
        next_step()
        return
      end

      db:load_all_metadata_bulk_async({
        on_complete = function(metadata, err)
          if metadata then
            -- Store with database prefix for lookup
            for key, value in pairs(metadata) do
              local full_key = string.format("%s:%s", db.db_name, key):lower()
              all_metadata[full_key] = value
            end
          end
          next_step()
        end,
        on_error = function(err)
          -- Continue even on error
          next_step()
        end,
      })
    end

    -- Step 2: Load all definitions in bulk
    local function load_definitions(next_step)
      if not db.load_all_definitions_bulk_async then
        next_step()
        return
      end

      db:load_all_definitions_bulk_async({
        on_complete = function(definitions, err)
          if definitions then
            -- Store with database prefix for lookup
            for key, value in pairs(definitions) do
              local full_key = string.format("%s:%s", db.db_name, key):lower()
              all_definitions[full_key] = value
            end
          end
          next_step()
        end,
        on_error = function(err)
          -- Continue even on error
          next_step()
        end,
      })
    end

    -- Run sequentially: metadata -> definitions -> callback
    load_metadata(function()
      load_definitions(function()
        db_callback()
      end)
    end)
  end

  -- Load databases sequentially to avoid overloading the server
  if total_dbs == 0 then
    apply_to_objects()
    return
  end

  local db_idx = 1

  local function load_next_database()
    if cancel_token and cancel_token.is_cancelled then
      stop_spinner_animation()
      ui_state.loading_status = "cancelled"
      ui_state.loading_message = "Metadata loading cancelled"
      if callback then callback() end
      return
    end

    if db_idx > total_dbs then
      -- All databases loaded, apply to objects
      apply_to_objects()
      return
    end

    local db = databases[db_idx]
    ui_state.loading_message = string.format("Loading metadata for %s (%d/%d)", db.db_name, db_idx, total_dbs)

    if multi_panel then
      multi_panel:render_panel("results")
    end

    load_database(db, function()
      completed_dbs = completed_dbs + 1
      ui_state.loading_progress = math.floor((completed_dbs / total_dbs) * 100)
      db_idx = db_idx + 1
      vim.schedule(load_next_database)
    end)
  end

  load_next_database()
end

---Load all objects for selected databases with async support and cancellation
---@param callback function? Callback when complete
local function load_objects_for_databases(callback)
  if not ui_state.selected_server then
    vim.notify("No server selected", vim.log.levels.WARN)
    return
  end

  -- Cancel any existing loading operation
  cancel_object_loading()

  local server = ui_state.selected_server
  local databases = {}

  -- Collect selected databases
  for _, db in pairs(ui_state.selected_databases) do
    table.insert(databases, db)
  end

  if #databases == 0 then
    vim.notify("No databases selected", vim.log.levels.WARN)
    return
  end

  -- Initialize loading state
  loading_cancel_token = Cancellation.create_token()
  ui_state.loading_status = "loading"
  ui_state.loading_progress = 0
  ui_state.loading_message = "Loading objects..."
  ui_state.loading_detail = nil
  -- Reset selection to top when loading new databases
  ui_state.selected_result_idx = 1
  ui_state.loaded_objects = {}

  -- Start spinner animation
  start_spinner_animation()

  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end

  -- Process databases in sequence using vim.schedule to avoid blocking
  local db_idx = 1
  local total_dbs = #databases
  local cancel_token = loading_cancel_token  -- Capture for closure

  ---Finalize loading (success or cancel)
  local function finalize_loading(status, message)
    ui_state.loading_detail = nil

    if status == "loaded" then
      ui_state.loading_progress = 100
      ui_state.loading_message = message or string.format("Loaded %d objects - loading references...", #ui_state.loaded_objects)

      -- Don't stop spinner yet - we're starting multi-pass loading:
      -- 1. Load databases referenced by cross-database synonyms
      -- 2. Preload metadata/definitions for all objects
      -- 3. Enable search
      load_synonym_referenced_databases_async(function()
        -- Now preload metadata for all databases (including newly loaded ones)
        ui_state.loading_message = string.format("Loaded %d objects - preloading metadata...", #ui_state.loaded_objects)
        if multi_panel then
          multi_panel:render_panel("results")
        end

        preload_metadata_async(function()
          -- Now search is ready - apply initial search filter
          UiObjectSearch._apply_search_async(ui_state.search_term, function()
            if multi_panel then
              multi_panel:render_all()
            end
            if callback then callback(status) end
          end)
        end)
      end)
      return
    elseif status == "cancelled" then
      stop_spinner_animation()
      loading_cancel_token = nil
      ui_state.loading_status = status
      ui_state.loading_message = "Loading cancelled"
      ui_state.search_ready = false

      -- Apply search to partial results if any (async handles its own rendering)
      if #ui_state.loaded_objects > 0 then
        -- Mark search as ready for partial results
        ui_state.search_ready = true
        UiObjectSearch._apply_search_async(ui_state.search_term, function()
          if multi_panel then
            multi_panel:render_all()
          end
          if callback then callback(status) end
        end)
        return
      end
    else
      stop_spinner_animation()
      loading_cancel_token = nil
      ui_state.loading_status = status
    end

    if multi_panel then
      multi_panel:render_all()
    end

    if callback then callback(status) end
  end

  ---Update loading detail and re-render
  local function update_detail(detail)
    ui_state.loading_detail = detail
    -- Note: Results panel is re-rendered by spinner timer
  end

  local function process_next_database()
    -- Check cancellation
    if cancel_token.is_cancelled then
      finalize_loading("cancelled")
      return
    end

    if db_idx > total_dbs then
      -- Done loading all databases
      finalize_loading("loaded")
      return
    end

    local db = databases[db_idx]
    ui_state.loading_message = string.format("Loading %s (%d/%d)", db.db_name, db_idx, total_dbs)
    ui_state.loading_progress = math.floor((db_idx - 1) / total_dbs * 100)

    ---Finalize this database and move to next
    local function finalize_db_and_continue()
      -- Check cancellation
      if cancel_token.is_cancelled then
        finalize_loading("cancelled")
        return
      end

      -- Flatten objects from this database
      update_detail("Processing objects...")
      local db_objects = flatten_database_objects(db, server)
      for _, obj in ipairs(db_objects) do
        table.insert(ui_state.loaded_objects, obj)
      end

      -- Apply search filter incrementally to show results as they load (async handles rendering)
      UiObjectSearch._apply_search_async(ui_state.search_term, function()
        -- Force display update so results are visible immediately
        vim.cmd('redraw')

        -- Move to next database
        db_idx = db_idx + 1
        vim.schedule(process_next_database)
      end)
    end

    ---Chain async operations with callbacks
    ---@param operations { name: string, fn: fun(on_done: fun(result: any)) }[]
    ---@param on_all_done fun()
    local function run_async_chain(operations, on_all_done)
      local op_idx = 1

      local function run_next()
        if cancel_token.is_cancelled then
          finalize_loading("cancelled")
          return
        end

        if op_idx > #operations then
          on_all_done()
          return
        end

        local op = operations[op_idx]
        update_detail(op.name)

        -- Re-render results panel to show current operation before blocking call
        if multi_panel then
          multi_panel:render_panel("results")
        end

        -- Force display update BEFORE blocking RPC call
        -- This ensures spinner/progress text is visible even if next call blocks
        vim.cmd('redraw')

        op.fn(function(result)
          op_idx = op_idx + 1
          vim.schedule(run_next)
        end)
      end

      vim.schedule(run_next)
    end

    -- Build async operation chain for this database
    -- Uses true non-blocking RPC async methods
    local operations = {
      {
        name = "Loading schemas...",
        fn = function(on_done)
          db:load_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading tables...",
        fn = function(on_done)
          db:load_tables_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading views...",
        fn = function(on_done)
          db:load_views_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading procedures...",
        fn = function(on_done)
          db:load_procedures_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading functions...",
        fn = function(on_done)
          db:load_functions_async({
            on_complete = function() on_done() end,
          })
        end,
      },
    }

    -- Add synonyms if supported
    if db.load_synonyms_async then
      table.insert(operations, {
        name = "Loading synonyms...",
        fn = function(on_done)
          db:load_synonyms_async({
            on_complete = function() on_done() end,
          })
        end,
      })
    end


    -- Start the async chain
    run_async_chain(operations, finalize_db_and_continue)
  end

  -- Start processing
  vim.schedule(process_next_database)
end

---Load definition for a searchable object
---@param searchable SearchableObject
---@return string? definition
local function load_definition(searchable)
  if searchable.definition_loaded then
    return searchable.definition
  end

  -- Check cache first
  if ui_state.definitions_cache[searchable.unique_id] then
    searchable.definition = ui_state.definitions_cache[searchable.unique_id]
    searchable.definition_loaded = true
    return searchable.definition
  end

  local obj = searchable.object
  if not obj then
    searchable.definition_loaded = true
    return nil
  end

  -- First try to get pre-loaded definition directly (no sync load)
  if obj.definition_loaded and obj.definition then
    searchable.definition = obj.definition
    searchable.definition_loaded = true
    ui_state.definitions_cache[searchable.unique_id] = obj.definition
    return obj.definition
  end

  -- For synonyms, try to get the base object's definition
  if searchable.object_type == "synonym" and obj.resolve then
    local ok, base_obj = pcall(function()
      return obj:resolve()
    end)
    if ok and base_obj and base_obj.definition_loaded and base_obj.definition then
      searchable.definition = base_obj.definition
      searchable.definition_loaded = true
      ui_state.definitions_cache[searchable.unique_id] = base_obj.definition
      return base_obj.definition
    end
  end

  -- Fallback: call get_definition() which may trigger a sync load
  -- Only do this for objects that weren't processed by bulk loaders
  if obj.get_definition then
    local ok, def = pcall(function()
      return obj:get_definition()
    end)

    if ok and def then
      searchable.definition = def
      searchable.definition_loaded = true
      ui_state.definitions_cache[searchable.unique_id] = def
      return def
    end
  end

  searchable.definition_loaded = true
  return nil
end

---Load metadata text for a searchable object (columns/parameters)
---@param searchable SearchableObject
---@return string? metadata_text
local function load_metadata_text(searchable)
  if searchable.metadata_loaded then
    return searchable.metadata_text
  end

  local obj = searchable.object
  local parts = {}

  -- For tables and views: get column names
  if searchable.object_type == "table" or searchable.object_type == "view" then
    if obj.get_columns then
      local ok, columns = pcall(function()
        return obj:get_columns()
      end)
      if ok and columns then
        for _, col in ipairs(columns) do
          table.insert(parts, col.name)
          if col.data_type then
            table.insert(parts, col.data_type)
          end
        end
      end
    end
  end

  -- For procedures and functions: get parameter names
  if searchable.object_type == "procedure" or searchable.object_type == "function" then
    if obj.get_parameters then
      local ok, params = pcall(function()
        return obj:get_parameters()
      end)
      if ok and params then
        for _, param in ipairs(params) do
          table.insert(parts, param.name)
          if param.data_type then
            table.insert(parts, param.data_type)
          end
        end
      end
    end
  end

  searchable.metadata_text = table.concat(parts, " ")
  searchable.metadata_loaded = true
  return searchable.metadata_text
end

-- ============================================================================
-- Search Functions
-- ============================================================================

---Check if text matches pattern
---@param text string Text to search in
---@param pattern string Search pattern
---@param regex table? Compiled regex
---@param pattern_lower string? Pre-computed lowercase pattern (for case-insensitive searches)
---@return boolean matched
---@return string? matched_text
local function text_matches_pattern(text, pattern, regex, pattern_lower)
  if not text or text == "" then
    return false, nil
  end

  if ui_state.use_regex and regex then
    local match_start = regex:match_str(text)
    if match_start then
      return true, text:sub(match_start + 1, match_start + #pattern)
    end
    return false, nil
  else
    -- Plain text mode
    local search_in = text
    local search_for = pattern
    if not ui_state.case_sensitive then
      search_in = text:lower()
      -- Use pre-computed lowercase pattern if available
      search_for = pattern_lower or pattern:lower()
    end

    if ui_state.whole_word then
      local start_pos = 1
      while true do
        local match_start, match_end = search_in:find(search_for, start_pos, true)
        if not match_start then
          return false, nil
        end
        if is_whole_word_match(search_in, match_start, match_end) then
          return true, text:sub(match_start, match_end)
        end
        start_pos = match_start + 1
      end
    else
      local match_start = search_in:find(search_for, 1, true)
      if match_start then
        return true, text:sub(match_start, match_start + #search_for - 1)
      end
      return false, nil
    end
  end
end

---Apply search filter asynchronously
---Uses OS threading when available for non-blocking execution,
---falls back to chunked processing when threading unavailable
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
function UiObjectSearch._apply_search_async(pattern, callback)
  -- Try threaded search first (always preferred for non-blocking UI)
  if Thread.is_available() then
    local started = UiObjectSearch._apply_search_threaded(pattern, callback)
    if started then
      return  -- Threaded search running
    end
    -- Thread failed to start, fall through to chunked processing
  end

  -- Fallback to chunked processing
  UiObjectSearch._apply_search_chunked(pattern, callback)
end

---Apply search using chunked processing with vim.schedule() yields
---This is the fallback when threading is unavailable or fails
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
function UiObjectSearch._apply_search_chunked(pattern, callback)
  -- Cancel any in-progress search
  if search_cancel_token then
    search_cancel_token:cancel("New search started")
  end

  -- Create new cancellation token
  search_cancel_token = Cancellation.create_token()
  local cancel_token = search_cancel_token

  local max_results = 500

  -- Pre-count objects that will be searched (after system/type filtering)
  local total_objects = 0
  for _, obj in ipairs(ui_state.loaded_objects) do
    if ui_state.show_system or not is_system_object(obj) then
      if should_show_object_type(obj) then
        total_objects = total_objects + 1
      end
    end
  end

  -- Handle empty pattern case: show all objects (no pattern matching)
  if not pattern or pattern == "" then
    ui_state.filtered_results = {}
    local count = 0
    for _, obj in ipairs(ui_state.loaded_objects) do
      if count >= max_results then break end
      -- Filter system objects unless show_system is enabled
      if ui_state.show_system or not is_system_object(obj) then
        -- Filter by object type
        if should_show_object_type(obj) then
          table.insert(ui_state.filtered_results, {
            searchable = obj,
            match_type = "none",
            match_details = {},
            display_name = build_display_name(obj),
            sort_priority = 0,
          })
          count = count + 1
        end
      end
    end
    search_cancel_token = nil
    search_in_progress = false
    search_progress = 0
    stop_search_spinner()
    -- Render panels with updated results
    if multi_panel then
      multi_panel:render_panel("results", { cursor_row = 1, cursor_col = 0 })
      multi_panel:render_panel("settings")
      multi_panel:render_panel("metadata")
      multi_panel:render_panel("definition")
    end
    if callback then callback() end
    return
  end

  -- Initialize search progress tracking
  search_in_progress = true
  search_progress = 0
  search_total_objects = total_objects
  search_start_time = vim.uv.hrtime()

  -- For small datasets, skip spinner (completes too fast to be useful)
  local use_progressive_display = total_objects >= SEARCH_CHUNK_SIZE
  if use_progressive_display then
    start_search_spinner()
  end

  -- Pre-compute search state
  local filtered = {}
  local regex = nil
  local pattern_lower = not ui_state.case_sensitive and pattern:lower() or nil

  -- Compile regex if in regex mode
  if ui_state.use_regex then
    local regex_pattern = pattern
    if ui_state.whole_word then
      regex_pattern = "\\<" .. regex_pattern .. "\\>"
    end
    if not ui_state.case_sensitive then
      regex_pattern = "\\c" .. regex_pattern
    end
    local ok, compiled = pcall(vim.regex, regex_pattern)
    if ok then
      regex = compiled
    end
  end

  -- Chunk processing state
  local idx = 1
  local chunk_size = SEARCH_CHUNK_SIZE

  ---Process one chunk of objects
  local function process_chunk()
    -- Check cancellation
    if cancel_token.is_cancelled then
      search_in_progress = false
      search_progress = 0
      stop_search_spinner()
      return
    end

    -- Process this chunk
    local end_idx = math.min(idx + chunk_size - 1, total_objects)

    -- Update progress
    search_progress = math.floor((end_idx / total_objects) * 100)

    for i = idx, end_idx do
      if #filtered >= max_results then break end

      local searchable = ui_state.loaded_objects[i]

      -- Filter system objects unless show_system is enabled
      if not ui_state.show_system and is_system_object(searchable) then
        goto continue_chunk
      end

      -- Filter by object type
      if not should_show_object_type(searchable) then
        goto continue_chunk
      end

      local match_details = {}
      local matched_name = false
      local matched_def = false
      local matched_meta = false

      -- Search in name
      if ui_state.search_names then
        local matched, matched_text = text_matches_pattern(searchable.name, pattern, regex, pattern_lower)
        if matched then
          matched_name = true
          table.insert(match_details, { field = "name", matched_text = matched_text or "" })
        end
      end

      -- Search in definition (lazy load)
      if ui_state.search_definitions and not matched_name then
        local definition = load_definition(searchable)
        if definition then
          local matched, matched_text = text_matches_pattern(definition, pattern, regex, pattern_lower)
          if matched then
            matched_def = true
            table.insert(match_details, { field = "definition", matched_text = matched_text or "" })
          end
        end
      end

      -- Search in metadata (lazy load)
      if ui_state.search_metadata and not matched_name and not matched_def then
        local metadata = load_metadata_text(searchable)
        if metadata then
          local matched, matched_text = text_matches_pattern(metadata, pattern, regex, pattern_lower)
          if matched then
            matched_meta = true
            table.insert(match_details, { field = "metadata", matched_text = matched_text or "" })
          end
        end
      end

      -- Add to results if any match
      if #match_details > 0 then
        local match_type = "name"
        local sort_priority = 3

        if matched_name then
          match_type = "name"
          sort_priority = 1
        elseif matched_def then
          match_type = "def"
          sort_priority = 2
        elseif matched_meta then
          match_type = "meta"
          sort_priority = 3
        end

        if #match_details > 1 then
          match_type = "multi"
        end

        table.insert(filtered, {
          searchable = searchable,
          match_type = match_type,
          match_details = match_details,
          display_name = build_display_name(searchable),
          sort_priority = sort_priority,
        })
      end

      ::continue_chunk::
    end

    idx = end_idx + 1

    -- Check if more chunks to process
    if idx <= total_objects and #filtered < max_results then
      -- For small datasets, process all in one go (no scheduling)
      if not use_progressive_display then
        -- Continue processing immediately without yielding
        return process_chunk()
      end

      -- Update intermediate results for progressive display
      ui_state.filtered_results = filtered

      -- Re-render results panel to show progress
      if multi_panel then
        multi_panel:render_panel("results")
        multi_panel:render_panel("filters")  -- Update match count
      end

      -- Schedule next chunk (only for large datasets)
      vim.schedule(process_chunk)
    else
      -- Done processing - finalize
      if cancel_token.is_cancelled then
        search_in_progress = false
        search_progress = 0
        stop_search_spinner()
        return
      end

      -- Sort by priority (name matches first)
      table.sort(filtered, function(a, b)
        if a.sort_priority ~= b.sort_priority then
          return a.sort_priority < b.sort_priority
        end
        return a.display_name < b.display_name
      end)

      ui_state.filtered_results = filtered

      -- Reset selection to top on new search results
      ui_state.selected_result_idx = 1

      -- Reset search progress state
      search_in_progress = false
      search_progress = 100
      search_cancel_token = nil
      stop_search_spinner()

      -- Final render
      if multi_panel then
        -- Render results with cursor at top
        multi_panel:render_panel("results", { cursor_row = 1, cursor_col = 0 })
        multi_panel:render_panel("filters")  -- Update match count
        multi_panel:render_panel("metadata")
        multi_panel:render_panel("definition")
      end

      if callback then callback() end
    end
  end

  -- Start processing first chunk immediately
  process_chunk()
end

---Cancel any in-progress async search (chunked or threaded)
function UiObjectSearch.cancel_search()
  -- Cancel chunked search token
  if search_cancel_token then
    search_cancel_token:cancel("Search cancelled")
    search_cancel_token = nil
  end
  -- Cancel threaded search
  if search_thread_task_id then
    Thread.cancel(search_thread_task_id, "Search cancelled")
    search_thread_task_id = nil
  end
  search_in_progress = false
  search_progress = 0
  stop_search_spinner()
end

---Check if an async search is in progress
---@return boolean
function UiObjectSearch.is_search_in_progress()
  return search_in_progress
end

---Apply search filter using OS thread for non-blocking execution
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
---@return boolean started Whether threaded search was started
function UiObjectSearch._apply_search_threaded(pattern, callback)
  -- Cancel any existing thread
  if search_thread_task_id then
    Thread.cancel(search_thread_task_id, "New search started")
    search_thread_task_id = nil
  end
  local total_objects = #ui_state.loaded_objects
  local max_results = 500

  -- Handle empty pattern case: show all objects (no pattern matching needed)
  if not pattern or pattern == "" then
    ui_state.filtered_results = {}
    local count = 0
    for _, obj in ipairs(ui_state.loaded_objects) do
      if count >= max_results then break end
      if ui_state.show_system or not is_system_object(obj) then
        if should_show_object_type(obj) then
          table.insert(ui_state.filtered_results, {
            searchable = obj,
            match_type = "none",
            match_details = {},
            display_name = build_display_name(obj),
            sort_priority = 0,
          })
          count = count + 1
        end
      end
    end
    search_in_progress = false
    search_progress = 0
    stop_search_spinner()
    -- Render panels with updated results
    if multi_panel then
      multi_panel:render_panel("results", { cursor_row = 1, cursor_col = 0 })
      multi_panel:render_panel("settings")
      multi_panel:render_panel("metadata")
      multi_panel:render_panel("definition")
    end
    if callback then callback() end
    return true
  end

  -- Clear existing results immediately when starting new search
  ui_state.filtered_results = {}
  if multi_panel then
    multi_panel:render_panel("results")
  end

  -- Prepare serializable objects for thread
  -- Extract only the data needed for searching (no class instances)
  -- Note: Metadata/definitions are preloaded asynchronously before search is enabled,
  -- so definition_loaded and metadata_loaded should be true for all objects
  local serializable_objects = {}
  for i, obj in ipairs(ui_state.loaded_objects) do
    -- Pre-filter system objects and object types to reduce thread work
    if ui_state.show_system or not is_system_object(obj) then
      if should_show_object_type(obj) then
        table.insert(serializable_objects, {
          idx = i,
          name = obj.name,
          schema_name = obj.schema_name,
          database_name = obj.database_name,
          server_name = obj.server_name,
          object_type = obj.object_type,
          display_name = build_display_name(obj),
          unique_id = obj.unique_id,
          -- Include preloaded data (loaded asynchronously before search was enabled)
          definition = ui_state.search_definitions and obj.definition or nil,
          metadata_text = ui_state.search_metadata and obj.metadata_text or nil,
        })
      end
    end
  end

  -- Initialize search progress tracking
  search_in_progress = true
  search_progress = 0
  search_total_objects = #serializable_objects
  search_start_time = vim.uv.hrtime()
  start_search_spinner()

  -- Accumulate results from batches
  local accumulated_results = {}

  -- Start threaded search
  local task_id, err = Thread.start({
    worker = "search",
    input = {
      objects = serializable_objects,
      pattern = pattern,
      options = {
        case_sensitive = ui_state.case_sensitive,
        use_regex = ui_state.use_regex,
        whole_word = ui_state.whole_word,
        search_names = ui_state.search_names,
        search_definitions = ui_state.search_definitions,
        search_metadata = ui_state.search_metadata,
        batch_interval_ms = 100,  -- Time-based batching: send results every 100ms
      },
    },
    on_batch = function(batch)
      -- Stream results to UI as they arrive
      for _, item in ipairs(batch.items or {}) do
        if #accumulated_results < max_results then
          -- Map back to SearchResult format using original object reference
          local original_obj = ui_state.loaded_objects[item.idx]
          if original_obj then
            table.insert(accumulated_results, {
              searchable = original_obj,
              match_type = item.match_type or "name",
              match_details = {{ field = item.match_type or "name", matched_text = "" }},
              display_name = item.display_name or build_display_name(original_obj),
              sort_priority = item.match_type == "name" and 1 or (item.match_type == "definition" and 2 or 3),
            })
          end
        end
      end

      -- Update UI with intermediate results
      ui_state.filtered_results = accumulated_results
      if batch.progress then
        search_progress = batch.progress
      end

      if multi_panel then
        multi_panel:render_panel("results")
        multi_panel:render_panel("filters")  -- Update match count
      end
    end,
    on_progress = function(pct, message)
      search_progress = pct
      -- Spinner handles re-rendering
    end,
    on_complete = function(result, error_msg)
      search_thread_task_id = nil

      if error_msg then
        -- Error occurred - fall back to non-threaded search
        vim.notify(
          string.format("[SSNS] Search thread error, falling back: %s", tostring(error_msg)),
          vim.log.levels.DEBUG
        )
        search_in_progress = false
        search_progress = 0
        stop_search_spinner()
        -- Fall back to chunked (non-threaded) search
        UiObjectSearch._apply_search_chunked(pattern, callback)
        return
      end

      if result and result.cancelled then
        -- Cancelled - don't update results
        search_in_progress = false
        search_progress = 0
        stop_search_spinner()
        return
      end

      -- Sort by priority (name matches first)
      table.sort(accumulated_results, function(a, b)
        if a.sort_priority ~= b.sort_priority then
          return a.sort_priority < b.sort_priority
        end
        return a.display_name < b.display_name
      end)

      ui_state.filtered_results = accumulated_results

      -- Reset selection to top on new search results
      ui_state.selected_result_idx = 1

      -- Finalize
      search_in_progress = false
      search_progress = 100
      stop_search_spinner()

      -- Final render
      if multi_panel then
        -- Render results with cursor at top
        multi_panel:render_panel("results", { cursor_row = 1, cursor_col = 0 })
        multi_panel:render_panel("filters")  -- Update match count
        multi_panel:render_panel("metadata")
        multi_panel:render_panel("definition")
      end

      if callback then callback() end
    end,
    timeout_ms = 30000,
  })

  if not task_id then
    -- Thread failed to start - log and return false so caller can fallback
    if err then
      vim.notify(string.format("[SSNS] Thread start failed: %s", err), vim.log.levels.WARN)
    end
    search_in_progress = false
    search_progress = 0
    stop_search_spinner()
    return false
  end

  search_thread_task_id = task_id
  return true
end


-- ============================================================================
-- Render Functions
-- ============================================================================

---Render the search panel (now just shows search input)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_search(state)
  local lines = {}
  local highlights = {}

  if ui_state.search_editing then
    return {""}, {}
  end

  -- Line 1: Search term or placeholder
  if ui_state.search_term == "" then
    table.insert(lines, " Press / to search")
    table.insert(highlights, {0, 0, -1, "Comment"})
  else
    table.insert(lines, " " .. ui_state.search_term)
    table.insert(highlights, {0, 0, -1, "SsnsUiHint"})
  end

  return lines, highlights
end

---Get selected search targets as values array
---@return string[]
local function get_search_targets_values()
  local values = {}
  if ui_state.search_names then table.insert(values, "names") end
  if ui_state.search_definitions then table.insert(values, "defs") end
  if ui_state.search_metadata then table.insert(values, "meta") end
  return values
end

---Get selected object types as values array
---@return string[]
local function get_object_types_values()
  local values = {}
  if ui_state.show_tables then table.insert(values, "table") end
  if ui_state.show_views then table.insert(values, "view") end
  if ui_state.show_procedures then table.insert(values, "procedure") end
  if ui_state.show_functions then table.insert(values, "function") end
  if ui_state.show_synonyms then table.insert(values, "synonym") end
  if ui_state.show_schemas then table.insert(values, "schema") end
  return values
end

---Invalidate the visible object count cache
---Called automatically by apply_current_search() when filters change
---Also called when loaded_objects changes to ensure count stays accurate
local function invalidate_visible_count_cache()
  ui_state._visible_count_cache = nil
end

---Calculate visible object count based on current filters (cached)
---@return number
local function get_visible_object_count()
  -- Return cached value if available
  if ui_state._visible_count_cache ~= nil then
    return ui_state._visible_count_cache
  end

  -- Calculate and cache
  local count = 0
  for _, obj in ipairs(ui_state.loaded_objects) do
    -- Check system filter
    if ui_state.show_system or not is_system_object(obj) then
      -- Check object type filter
      if should_show_object_type(obj) then
        count = count + 1
      end
    end
  end

  ui_state._visible_count_cache = count
  return count
end

---Render the filters panel (filter toggles + status/counts)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_filters(state)
  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["filters"] and state.panels["filters"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Search targets dropdown (what to search in)
  cb:multi_dropdown("search_targets", {
    label = "Search In",
    label_width = 11,
    options = {
      { value = "names", label = "Names {1}" },
      { value = "defs", label = "Definitions {2}" },
      { value = "meta", label = "Metadata {3}" },
    },
    values = get_search_targets_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 70,
  })

  -- Row 2: Object types dropdown (what types to show)
  cb:multi_dropdown("object_types", {
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
    values = get_object_types_values(),
    display_mode = "list",
    select_all_option = true,
    placeholder = "(none)",
    width = 70,
  })

  -- Row 3: Status/counts
  if ui_state.loading_status == "loading" then
    local filled = math.floor(ui_state.loading_progress / 10)
    local progress_bar = string.rep("█", filled) .. string.rep("░", 10 - filled)
    cb:spans({
      { text = " [", style = "muted" },
      { text = progress_bar, style = "success" },
      { text = "] ", style = "muted" },
      { text = string.format("%d%%", ui_state.loading_progress), style = "value" },
      { text = " " .. ui_state.loading_message, style = "comment" },
    })
  elseif ui_state.selected_server then
    cb:spans({
      { text = " Objects: ", style = "muted" },
      { text = tostring(get_visible_object_count()), style = "value" },
      { text = " | Matches: ", style = "muted" },
      { text = tostring(#ui_state.filtered_results), style = "value" },
    })
  else
    cb:styled(" Select a server to search", "muted")
  end

  return cb:build_lines(), cb:build_highlights()
end

---Build server dropdown options from cache and connections
---Uses cached saved connections (loaded async on panel open)
---@return DropdownOption[] options
local function get_server_options()
  local options = {}
  local seen = {}

  -- Connected servers first
  for _, server in ipairs(Cache.servers) do
    if not seen[server.name] then
      seen[server.name] = true
      local status = server:is_connected() and "● " or "○ "
      table.insert(options, {
        value = server.name,
        label = status .. server.name,
      })
    end
  end

  -- Saved connections (from async cache)
  local saved_connections = ui_state._cached_saved_connections or {}
  for _, conn in ipairs(saved_connections) do
    if not seen[conn.name] then
      seen[conn.name] = true
      table.insert(options, {
        value = conn.name,
        label = "○ " .. conn.name,
      })
    end
  end

  -- Config connections
  local Config = require('ssns.config')
  local config_connections = Config.get_connections()
  for name, _ in pairs(config_connections) do
    if not seen[name] then
      seen[name] = true
      table.insert(options, {
        value = name,
        label = "○ " .. name,
      })
    end
  end

  return options
end

---Build database dropdown options from selected server
---Note: This function only reads cached data - async loading is handled by server dropdown change handler
---@return DropdownOption[] options
local function get_database_options()
  local options = {}

  if not ui_state.selected_server then
    return options
  end

  local server = ui_state.selected_server

  -- Ensure server is connected and loaded
  -- Don't trigger loading here - it's handled asynchronously by the server dropdown handler
  if not server:is_connected() or not server.is_loaded then
    return options
  end

  -- Get databases directly from server (already loaded)
  local databases = server.databases or {}

  for _, db in ipairs(databases) do
    -- Skip system databases if show_system is false
    if ui_state.show_system or not SYSTEM_DATABASES[db.db_name] then
      table.insert(options, {
        value = db.db_name,
        label = db.db_name,
      })
    end
  end

  return options
end

---Get currently selected database names as array
---@return string[] names
local function get_selected_db_names()
  local names = {}
  for name, _ in pairs(ui_state.selected_databases) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

---Get selected search options as values array
---@return string[]
local function get_search_options_values()
  local values = {}
  if ui_state.case_sensitive then table.insert(values, "case") end
  if ui_state.use_regex then table.insert(values, "regex") end
  if ui_state.whole_word then table.insert(values, "word") end
  if ui_state.show_system then table.insert(values, "system") end
  return values
end

---Render the settings panel with dropdowns and toggles
---@param state MultiPanelState
---@return ContentBuilder cb
render_settings = function(state)
  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["settings"] and state.panels["settings"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Server dropdown
  cb:dropdown("server", {
    label = "Server",
    label_width = 11,
    options = get_server_options(),
    value = ui_state.selected_server and ui_state.selected_server.name or "",
    placeholder = "(select server)",
    width = 70,
  })

  -- Row 2: Database multi-dropdown (show loading state when server is connecting/loading)
  local db_placeholder = "(select databases)"
  local db_options = {}
  local db_disabled = false

  if ui_state.server_loading then
    -- Show loading spinner in placeholder
    local spinner_char = loading_text_spinner and loading_text_spinner:get_frame() or "⠋"
    db_placeholder = spinner_char .. " Loading databases..."
    db_disabled = true
  elseif not ui_state.selected_server then
    db_placeholder = "(select server first)"
    db_disabled = true
  else
    db_options = get_database_options()
    if #db_options == 0 then
      db_placeholder = "(no databases found)"
      db_disabled = true
    end
  end

  cb:multi_dropdown("databases", {
    label = "Databases",
    label_width = 11,
    options = db_options,
    values = get_selected_db_names(),
    display_mode = "count",
    select_all_option = not db_disabled,
    placeholder = db_placeholder,
    width = 70,
    disabled = db_disabled,
  })

  -- Row 3: Search options multi-dropdown (list mode)
  cb:multi_dropdown("search_options", {
    label = "Options",
    label_width = 11,
    options = {
      { value = "case", label = "Case {c}" },
      { value = "regex", label = "Regex {x}" },
      { value = "word", label = "Word {w}" },
      { value = "system", label = "Sys Objs {S}" },
    },
    values = get_search_options_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 70,
  })

  return cb
end

---Render the results panel
---Get object type style name for ContentBuilder
---@param object_type string
---@return string style
local function get_object_style(object_type)
  local styles = {
    table = "table",
    view = "view",
    procedure = "procedure",
    ["function"] = "func",
    synonym = "muted",
    schema = "schema",
  }
  return styles[object_type] or "normal"
end

---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_results(state)
  local cb = ContentBuilder.new()

  -- Show loading status header when loading (but continue to show results below)
  if ui_state.loading_status == "loading" and loading_text_spinner then
    -- Animated spinner with runtime (using TextSpinner with user's configured style)
    local spinner_char = loading_text_spinner:get_frame()
    local runtime = loading_text_spinner:get_runtime()

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "success" },
      { text = " ", style = "normal" },
      { text = ui_state.loading_message, style = "emphasis" },
      { text = " · ", style = "muted" },
      { text = runtime, style = "value" },
      { text = " · ", style = "muted" },
      { text = "<C-c>", style = "comment" },
      { text = " cancel", style = "muted" },
    })

    if ui_state.loading_detail then
      cb:spans({
        { text = " ", style = "normal" },
        { text = ui_state.loading_detail, style = "comment" },
      })
    end

    -- Show match count if we have results
    if #ui_state.filtered_results > 0 then
      cb:spans({
        { text = " Matches: ", style = "muted" },
        { text = tostring(#ui_state.filtered_results), style = "value" },
        { text = " (loading more...)", style = "comment" },
      })
    end

    cb:blank()
  end

  -- Show cancelled status header
  if ui_state.loading_status == "cancelled" then
    cb:spans({
      { text = " ", style = "normal" },
      { text = "✗", style = "error" },
      { text = " Loading cancelled", style = "warning" },
      { text = " · ", style = "muted" },
      { text = tostring(#ui_state.loaded_objects), style = "value" },
      { text = " objects loaded", style = "muted" },
    })
    cb:blank()
  end

  -- Show search filtering progress when actively searching (separate from object loading)
  if search_in_progress and search_text_spinner then
    local spinner_char = search_text_spinner:get_frame()
    local elapsed = get_search_elapsed_time()
    local total = search_total_objects
    local searched = math.floor(total * search_progress / 100)

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "warning" },
      { text = " Filtering: ", style = "emphasis" },
      { text = tostring(searched), style = "value" },
      { text = "/", style = "muted" },
      { text = tostring(total), style = "value" },
      { text = string.format(" (%d%%)", search_progress), style = "muted" },
      { text = " · ", style = "muted" },
      { text = elapsed, style = "value" },
      { text = " · ", style = "muted" },
      { text = tostring(#ui_state.filtered_results), style = "success" },
      { text = " matches", style = "muted" },
    })
    cb:blank()
  end

  -- Results list (show during loading AND after)
  for i, result in ipairs(ui_state.filtered_results) do
    local is_selected = (i == ui_state.selected_result_idx)
    local prefix = is_selected and " ▶ " or "   "
    local icon = get_object_icon(result.searchable.object_type)
    local obj_style = get_object_style(result.searchable.object_type)
    local badge = result.match_type ~= "none" and string.format(" [%s]", result.match_type) or ""

    local spans = {
      { text = prefix, style = is_selected and "highlight" or "normal" },
      { text = icon .. " ", style = is_selected and "strong" or obj_style },
      { text = result.searchable.database_name, style = is_selected and "strong" or "database" },
      { text = ".", style = is_selected and "strong" or "muted" },
      { text = result.display_name, style = is_selected and "strong" or obj_style },
    }

    if badge ~= "" then
      table.insert(spans, { text = badge, style = "muted" })
    end

    cb:spans(spans)
  end

  if #ui_state.filtered_results == 0 then
    if ui_state.loading_status == "loading" then
      -- Don't show "no matches" during loading - more results may come
      if #ui_state.loaded_objects == 0 then
        cb:styled("   Waiting for objects...", "comment")
      end
    elseif #ui_state.loaded_objects == 0 then
      cb:styled("   Press 'd' to select databases and load objects", "comment")
    else
      cb:styled("   (No matches)", "comment")
    end
  end

  return cb:build_lines(), cb:build_highlights()
end

---Render the metadata panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_metadata(state)
  local cb = ContentBuilder.new()

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    cb:blank()
    cb:styled(" Select an object to view metadata", "comment")
    return cb:build_lines(), cb:build_highlights()
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable
  local obj = searchable.object
  local obj_style = get_object_style(searchable.object_type)

  -- Header
  cb:blank()
  cb:spans({
    { text = " ", style = "normal" },
    { text = searchable.object_type:upper(), style = "muted" },
    { text = ": ", style = "muted" },
    { text = searchable.name, style = obj_style },
  })

  cb:spans({
    { text = " Schema: ", style = "label" },
    { text = searchable.schema_name or "N/A", style = "schema" },
  })

  cb:spans({
    { text = " Database: ", style = "label" },
    { text = searchable.database_name, style = "database" },
  })

  cb:blank()

  -- Object-specific metadata
  if searchable.object_type == "table" or searchable.object_type == "view" then
    -- Show columns
    cb:section(" Columns:")

    if obj and obj.get_columns then
      local ok, columns = pcall(function()
        return obj:get_columns({ skip_load = true })
      end)

      if ok and columns and #columns > 0 then
        for _, col in ipairs(columns) do
          local nullable_style = col.nullable and "muted" or "warning"
          local nullable_text = col.nullable and "NULL" or "NOT NULL"
          cb:spans({
            { text = "   ", style = "normal" },
            { text = col.name, style = "column" },
            { text = " (", style = "muted" },
            { text = col.data_type or "?", style = "keyword" },
            { text = ") ", style = "muted" },
            { text = nullable_text, style = nullable_style },
          })
        end
      else
        cb:styled("   (Load object to see columns)", "comment")
      end
    end
  elseif searchable.object_type == "procedure" or searchable.object_type == "function" then
    -- Show parameters
    cb:section(" Parameters:")

    if obj and obj.get_parameters then
      local ok, params = pcall(function()
        return obj:get_parameters({ skip_load = true })
      end)

      if ok and params and #params > 0 then
        for _, param in ipairs(params) do
          local direction = param.is_output and "OUT" or "IN"
          local dir_style = param.is_output and "warning" or "success"
          cb:spans({
            { text = "   ", style = "normal" },
            { text = direction, style = dir_style },
            { text = " ", style = "normal" },
            { text = param.name, style = "param" },
            { text = " (", style = "muted" },
            { text = param.data_type or "?", style = "keyword" },
            { text = ")", style = "muted" },
          })
        end
      else
        cb:styled("   (Load object to see parameters)", "comment")
      end
    end
  elseif searchable.object_type == "synonym" then
    -- Show synonym target
    cb:section(" Target:")

    if obj and obj.base_object_name then
      cb:spans({
        { text = "   ", style = "normal" },
        { text = obj.base_object_name, style = "table" },
      })
    else
      cb:styled("   (Unknown)", "comment")
    end
  elseif searchable.object_type == "schema" then
    -- Schema info
    cb:section(" Schema Info:")
    cb:styled("   Schema object - no additional metadata", "comment")
  end

  return cb:build_lines(), cb:build_highlights()
end

---Render the definition panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_definition(state)
  local lines = {}
  local highlights = {}

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    table.insert(lines, "-- Select an object to view definition")
    return lines, highlights
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Header comments
  table.insert(lines, string.format("-- %s: %s", searchable.object_type:upper(), searchable.name))
  -- Show database and schema (only include schema if it exists and is meaningful)
  local db_display = searchable.database_name
  if searchable.schema_name and searchable.schema_name ~= "" then
    db_display = string.format("%s.%s", searchable.database_name, searchable.schema_name)
  end
  table.insert(lines, string.format("-- Database: %s", db_display))
  table.insert(lines, string.format("-- Server: %s", searchable.server_name))
  table.insert(lines, "")

  -- Get definition
  local definition = load_definition(searchable)

  if definition then
    for _, def_line in ipairs(vim.split(definition, "\n")) do
      table.insert(lines, def_line)
    end
  else
    table.insert(lines, "-- Definition not available")
    table.insert(lines, "-- (Schema objects and some system objects may not have definitions)")
  end

  -- Highlight header comments
  for i = 0, 3 do
    if lines[i + 1] and lines[i + 1]:match("^%-%-") then
      table.insert(highlights, {i, 0, -1, "Comment"})
    end
  end

  return lines, highlights
end

-- ============================================================================
-- Search Mode Functions
-- ============================================================================


---Finalize search exit
local function finalize_search_exit()
  ui_state.search_editing = false

  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    vim.api.nvim_buf_set_option(search_buf, 'modifiable', false)
  end

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    search_augroup = nil
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
local function cancel_search()
  ui_state.search_term = ui_state.search_term_before_edit
  -- NOTE: Do NOT trigger search here - let any running thread continue.
  -- The current results are still valid (they match the reverted term).
  vim.cmd('stopinsert')
end

---Commit search (Enter)
---Reads from buffer and triggers a new search.
local function commit_search()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local new_term = (lines[1] or ""):gsub("^%s+", "")

    -- Only trigger search if term actually changed
    if new_term ~= ui_state.search_term then
      ui_state.search_term = new_term
      -- Trigger the search (will use threaded version when available)
      UiObjectSearch._apply_search_async(new_term)
    end
  end
  vim.cmd('stopinsert')
end

---Helper to apply search from current search term or buffer
local function apply_current_search()
  -- Invalidate visible count cache since filters may have changed
  invalidate_visible_count_cache()

  -- Only read from buffer if we're actively editing the search
  if ui_state.search_editing then
    local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
    if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
      local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
      local text = (lines[1] or ""):gsub("^%s+", "")
      UiObjectSearch._apply_search_async(text)
      return
    end
  end
  -- Use committed search term (async handles rendering)
  UiObjectSearch._apply_search_async(ui_state.search_term)
end

---Sync filter dropdown values with current ui_state
---Call this after changing filter state via hotkeys to update the dropdowns
local function sync_filter_dropdowns()
  if not multi_panel then return end

  local filters_panel = multi_panel.panels["filters"]
  if not filters_panel or not filters_panel.input_manager then return end

  local input_manager = filters_panel.input_manager

  -- Sync search_targets dropdown
  input_manager:set_multi_dropdown_values("search_targets", get_search_targets_values())

  -- Sync object_types dropdown
  input_manager:set_multi_dropdown_values("object_types", get_object_types_values())
end

---Sync settings dropdown values with current ui_state
---Call this after changing settings state via hotkeys to update the dropdowns
local function sync_settings_dropdowns()
  if not multi_panel then return end

  local settings_panel = multi_panel.panels["settings"]
  if not settings_panel or not settings_panel.input_manager then return end

  local input_manager = settings_panel.input_manager

  -- Sync search_options dropdown
  input_manager:set_multi_dropdown_values("search_options", get_search_options_values())
end

---Toggle functions for search settings
local function toggle_case_sensitive()
  ui_state.case_sensitive = not ui_state.case_sensitive
  apply_current_search()
  sync_settings_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
  end
  vim.notify("Case sensitive: " .. (ui_state.case_sensitive and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_regex()
  ui_state.use_regex = not ui_state.use_regex
  apply_current_search()
  sync_settings_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
  end
  vim.notify("Regex: " .. (ui_state.use_regex and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_whole_word()
  ui_state.whole_word = not ui_state.whole_word
  apply_current_search()
  sync_settings_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
  end
  vim.notify("Whole word: " .. (ui_state.whole_word and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_search_names()
  ui_state.search_names = not ui_state.search_names
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("settings")
  end
  vim.notify("Search names: " .. (ui_state.search_names and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_search_defs()
  ui_state.search_definitions = not ui_state.search_definitions
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("settings")
  end
  vim.notify("Search definitions: " .. (ui_state.search_definitions and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_search_meta()
  ui_state.search_metadata = not ui_state.search_metadata
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("settings")
  end
  vim.notify("Search metadata: " .. (ui_state.search_metadata and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_system()
  ui_state.show_system = not ui_state.show_system
  apply_current_search()
  sync_settings_dropdowns()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
  end
  vim.notify("Show system: " .. (ui_state.show_system and "ON" or "OFF"), vim.log.levels.INFO)
end

---Toggle functions for object type filters
local function toggle_tables()
  ui_state.show_tables = not ui_state.show_tables
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show tables: " .. (ui_state.show_tables and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_views()
  ui_state.show_views = not ui_state.show_views
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show views: " .. (ui_state.show_views and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_procedures()
  ui_state.show_procedures = not ui_state.show_procedures
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show procedures: " .. (ui_state.show_procedures and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_functions()
  ui_state.show_functions = not ui_state.show_functions
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show functions: " .. (ui_state.show_functions and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_synonyms()
  ui_state.show_synonyms = not ui_state.show_synonyms
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show synonyms: " .. (ui_state.show_synonyms and "ON" or "OFF"), vim.log.levels.INFO)
end

local function toggle_schemas()
  ui_state.show_schemas = not ui_state.show_schemas
  apply_current_search()
  sync_filter_dropdowns()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("filters")
  end
  vim.notify("Show schemas: " .. (ui_state.show_schemas and "ON" or "OFF"), vim.log.levels.INFO)
end

---Setup search autocmds
local function setup_search_autocmds()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
  end

  search_augroup = vim.api.nvim_create_augroup("SSNSObjectSearch", { clear = true })

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
      finalize_search_exit()
    end,
  })

  -- Setup keymaps
  KeymapManager.set(search_buf, 'i', '<Esc>', cancel_search, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<Tab>', commit_search, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<CR>', commit_search, { nowait = true })

  -- Search settings toggles (consistent with normal mode keymaps)
  KeymapManager.set(search_buf, 'i', '<A-c>', toggle_case_sensitive, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-x>', toggle_regex, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-w>', toggle_whole_word, { nowait = true })

  -- Search context toggles
  KeymapManager.set(search_buf, 'i', '<A-1>', toggle_search_names, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-2>', toggle_search_defs, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-3>', toggle_search_meta, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-S>', toggle_system, { nowait = true })

  -- Object type toggles (Alt+Shift+number)
  KeymapManager.set(search_buf, 'i', '<A-!>', toggle_tables, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-@>', toggle_views, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-#>', toggle_procedures, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-$>', toggle_functions, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-%>', toggle_synonyms, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-^>', toggle_schemas, { nowait = true })

  KeymapManager.setup_auto_restore(search_buf)
end

---Activate search mode
local function activate_search()
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

  setup_search_autocmds()
end

-- ============================================================================
-- Navigation Functions
-- ============================================================================

---Open selected object's definition in new buffer
local function open_in_buffer()
  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    return
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Get definition
  local definition = load_definition(searchable)

  if not definition then
    vim.notify("No definition available for this object", vim.log.levels.WARN)
    return
  end

  -- Find server and database objects
  local server = Cache.find_server(searchable.server_name)
  local database = nil
  if server then
    database = Cache.find_database(searchable.server_name, searchable.database_name)
  end

  -- Close search window
  UiObjectSearch.close()

  -- Create new query buffer
  UiQuery.create_query_buffer(server or searchable.server_name, database or searchable.database_name)

  vim.schedule(function()
    local query_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(query_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, vim.split(definition, "\n"))

    vim.notify(string.format("Opened definition: %s.%s",
      searchable.database_name, searchable.name), vim.log.levels.INFO)
  end)
end

---Yank object name to clipboard
local function yank_object_name()
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
local function select_or_exec_in_buffer()
  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    return
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable

  -- Find the actual object from cache
  local server = Cache.find_server(searchable.server_name)
  local database = server and Cache.find_database(searchable.server_name, searchable.database_name)
  local schema = database and Cache.find_schema(searchable.server_name, searchable.database_name, searchable.schema_name)

  if not schema then
    vim.notify("Could not find schema for object", vim.log.levels.WARN)
    return
  end

  local obj = nil
  local obj_type = searchable.object_type

  -- Find the object based on type
  if obj_type == "table" then
    obj = schema:find_table(searchable.name)
  elseif obj_type == "view" then
    obj = schema:find_view(searchable.name)
  elseif obj_type == "synonym" then
    obj = schema:find_synonym(searchable.name)
  elseif obj_type == "procedure" then
    -- Find procedure in schema's procedures list
    local procedures = schema:get_procedures({ skip_load = true })
    for _, proc in ipairs(procedures) do
      if proc.name == searchable.name then
        obj = proc
        break
      end
    end
  elseif obj_type == "function" then
    -- Find function in schema's functions list
    local functions = schema:get_functions({ skip_load = true })
    for _, func in ipairs(functions) do
      if func.name == searchable.name then
        obj = func
        break
      end
    end
  end

  if not obj then
    vim.notify("Could not find object: " .. searchable.name, vim.log.levels.WARN)
    return
  end

  -- Close search window
  UiObjectSearch.close()

  -- Generate and execute the appropriate statement
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
            server.name,
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

      -- Load parameters if needed
      if obj.parameters then
        show_exec_ui(obj.parameters)
      elseif obj.load_parameters then
        obj:load_parameters()
        show_exec_ui(obj.parameters)
      else
        local sql = obj:generate_exec()
        UiQuery.create_query_buffer(server, database, sql, obj.name)
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
  local UiFloatInteractive = require('ssns.ui.base.float_interactive')
  local ContentBuilder = require('ssns.ui.core.content_builder')
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
local function show_server_picker()
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
  if not ui_state.selected_server then
    vim.notify("Select a server first", vim.log.levels.WARN)
    return
  end

  local server = ui_state.selected_server
  local UiFloatInteractive = require('ssns.ui.base.float_interactive')
  local ContentBuilder = require('ssns.ui.core.content_builder')

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
            { text = db.db_name, style = "database" },
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
          load_objects_for_databases()
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

---Refresh objects (reload from database)
local function refresh_objects()
  if not ui_state.selected_server then
    vim.notify("Select a server first", vim.log.levels.WARN)
    return
  end

  -- Clear caches
  ui_state.definitions_cache = {}
  ui_state.loaded_objects = {}
  ui_state.filtered_results = {}

  -- Reload
  load_objects_for_databases()
end

-- ============================================================================
-- Public API
-- ============================================================================

---Close the object search window
function UiObjectSearch.close()
  -- Cancel any active loading operation
  cancel_object_loading()

  -- Cancel any active search (chunked or threaded)
  UiObjectSearch.cancel_search()

  -- Stop spinner animation
  stop_spinner_animation()

  -- Clear loading state
  loading_cancel_token = nil

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    search_augroup = nil
  end

  if multi_panel then
    multi_panel:close()
    multi_panel = nil
  end

  -- Save state for next open (don't reset - preserve user's work)
  save_current_state()
end

---Show the object search UI
---@param options table? Options {server?: ServerClass, database?: DbClass, reset?: boolean}
function UiObjectSearch.show(options)
  options = options or {}

  -- Close existing panel (saves state)
  if multi_panel then
    multi_panel:close()
    multi_panel = nil
  end

  -- Check if we should restore saved state or start fresh
  local restored = false
  if not options.reset and saved_state then
    -- Restore previous state
    reset_state()  -- Clear current state first
    restored = restore_saved_state()
  else
    -- Fresh start
    reset_state(true)  -- Clear saved state too
  end

  -- Load saved connections asynchronously (for server dropdown)
  local Connections = require('ssns.connections')
  Connections.load_async(function(connections, err)
    if not err then
      ui_state._cached_saved_connections = connections
      -- Re-render settings panel if it exists to show new server options
      vim.schedule(function()
        if multi_panel and multi_panel:is_valid() then
          local new_cb = render_settings(multi_panel)
          multi_panel:update_inputs("settings", new_cb)
          multi_panel:render_panel("settings")
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
              on_render = render_search,
            },
            {
              name = "settings",
              title = "Settings",
              ratio = 0.60,
              focusable = true,
              cursorline = false,
              on_render = function(state)
                local cb = render_settings(state)
                return cb:build_lines(), cb:build_highlights()
              end,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("settings", "Settings ●")
                  multi_panel:update_panel_title("results", "Results")
                  multi_panel:update_panel_title("metadata", "Metadata")
                  multi_panel:update_panel_title("definition", "Definition")
                  -- Position cursor on the first dropdown (server)
                  vim.schedule(function()
                    if multi_panel and multi_panel:is_valid() then
                      local settings_panel = multi_panel.panels["settings"]
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
                  on_render = render_filters,
                  on_focus = function()
                    if multi_panel then
                      multi_panel:update_panel_title("settings", "Settings")
                      multi_panel:update_panel_title("filters", "Filters ●")
                      multi_panel:update_panel_title("results", "Results")
                      multi_panel:update_panel_title("metadata", "Metadata")
                      multi_panel:update_panel_title("definition", "Definition")
                    end
                  end,
                },
                {
                  name = "results",
                  title = "Results",
                  ratio = 0.95,
                  focusable = true,
                  cursorline = true,
                  on_render = render_results,
                  on_focus = function()
                    if multi_panel then
                      multi_panel:update_panel_title("settings", "Settings")
                      multi_panel:update_panel_title("filters", "Filters")
                      multi_panel:update_panel_title("results", "Results ●")
                      -- Keep the last right panel indicator
                      if last_right_panel == "metadata" then
                        multi_panel:update_panel_title("metadata", "Metadata")
                        multi_panel:update_panel_title("definition", "Definition")
                      else
                        multi_panel:update_panel_title("metadata", "Metadata")
                        multi_panel:update_panel_title("definition", "Definition")
                      end
                      -- Position cursor on currently selected result (deferred to handle chunked rendering)
                      vim.schedule(function()
                        if multi_panel and multi_panel:is_valid() then
                          local target_line = math.max(1, ui_state.selected_result_idx)
                          -- Re-render with cursor position to ensure it's set after any pending chunks
                          multi_panel:render_panel("results", { cursor_row = target_line, cursor_col = 0 })
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
                  on_render = render_metadata,
                  on_focus = function()
                    last_right_panel = "metadata"
                    if multi_panel then
                      multi_panel:update_panel_title("settings", "Settings")
                      multi_panel:update_panel_title("filters", "Filters")
                      multi_panel:update_panel_title("results", "Results")
                      multi_panel:update_panel_title("metadata", "Metadata ●")
                      multi_panel:update_panel_title("definition", "Definition")
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
                  on_render = render_definition,
                  on_pre_filetype = function(bufnr)
                    vim.b[bufnr].ssns_skip_semantic_highlight = true
                  end,
                  use_basic_highlighting = true,
                  on_focus = function()
                    last_right_panel = "definition"
                    if multi_panel then
                      multi_panel:update_panel_title("settings", "Settings")
                      multi_panel:update_panel_title("filters", "Filters")
                      multi_panel:update_panel_title("results", "Results")
                      multi_panel:update_panel_title("metadata", "Metadata")
                      multi_panel:update_panel_title("definition", "Definition ●")
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
      if search_augroup then
        pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
        search_augroup = nil
      end
      -- Save state before closing (preserve user's work)
      save_current_state()
      multi_panel = nil
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Setup inputs for settings panel (enables dropdowns)
  local settings_cb = render_settings(multi_panel)
  multi_panel:setup_inputs("settings", settings_cb, {
    on_dropdown_change = function(key, value)
      if key == "server" then
        -- Server changed - find or create server and connect
        local server = Cache.find_server(value)

        if not server then
          local Connections = require('ssns.connections')
          local conn = Connections.find_by_name(value)
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
          start_spinner_animation()

          -- Update UI to show loading state immediately
          local new_cb = render_settings(multi_panel)
          multi_panel:update_inputs("settings", new_cb)
          multi_panel:render_panel("settings")
          multi_panel:render_panel("results")

          -- Use true non-blocking RPC async (UI stays responsive)
          server:connect_and_load_async({
            on_complete = function(success, err)
              -- Stop loading state
              ui_state.server_loading = false
              stop_spinner_animation()

              if not success then
                vim.notify("Failed to connect to " .. value .. ": " .. (err or "Unknown error"), vim.log.levels.ERROR)
              end

              -- Refresh settings panel to show database options
              if multi_panel and multi_panel:is_valid() then
                local final_cb = render_settings(multi_panel)
                multi_panel:update_inputs("settings", final_cb)
                multi_panel:render_panel("settings")
                multi_panel:render_panel("results")
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
          load_objects_for_databases()
        else
          -- Clear results if no databases selected
          ui_state.loaded_objects = {}
          ui_state.filtered_results = {}
          multi_panel:render_panel("results")
        end
      elseif key == "search_options" then
        -- Update search options state from dropdown
        ui_state.case_sensitive = vim.tbl_contains(values, "case")
        ui_state.use_regex = vim.tbl_contains(values, "regex")
        ui_state.whole_word = vim.tbl_contains(values, "word")
        ui_state.show_system = vim.tbl_contains(values, "system")
        apply_current_search()
        sync_filter_dropdowns()  -- Show system affects object count in filters
        multi_panel:render_panel("results")
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
    values = get_search_targets_values(),
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
    values = get_object_types_values(),
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
        apply_current_search()
        multi_panel:render_panel("results")
        multi_panel:render_panel("filters")
      elseif key == "object_types" then
        -- Update object type state from dropdown
        ui_state.show_tables = vim.tbl_contains(values, "table")
        ui_state.show_views = vim.tbl_contains(values, "view")
        ui_state.show_procedures = vim.tbl_contains(values, "procedure")
        ui_state.show_functions = vim.tbl_contains(values, "function")
        ui_state.show_synonyms = vim.tbl_contains(values, "synonym")
        ui_state.show_schemas = vim.tbl_contains(values, "schema")
        apply_current_search()
        multi_panel:render_panel("results")
        multi_panel:render_panel("filters")
      end
    end,
  })

  -- Position cursor on the first dropdown (server) in settings panel
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() then
      local settings_panel = multi_panel.panels["settings"]
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

  local function focus_server_dropdown()
    -- Focus the server dropdown in the settings panel
    multi_panel:focus_field("settings", "server")
  end

  local function focus_database_dropdown()
    -- Focus the database multi-dropdown in the settings panel
    multi_panel:focus_field("settings", "databases")
  end

  local function focus_filters_panel()
    multi_panel:focus_panel("filters")
  end

  local function focus_settings_panel()
    -- Focus the first field (server dropdown) in the settings panel
    multi_panel:focus_first_field("settings")
  end

  -- Custom Tab navigation: results <-> last right panel (definition/metadata)
  local function navigate_tab()
    local current_panel = multi_panel.focused_panel
    if current_panel == "results" then
      -- Jump to last focused right panel
      multi_panel:focus_panel(last_right_panel)
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
      multi_panel:focus_panel(last_right_panel)
    end
  end

  -- Common keymaps shared by all panels
  -- All letter keys use Alt+ modifier to preserve default Neovim controls
  local function get_common_keymaps()
    return {
      [common.close or "<A-q>"] = function() UiObjectSearch.close() end,
      [common.cancel or "<Esc>"] = function() UiObjectSearch.close() end,
      ["<C-c>"] = function()
        -- Cancel object loading if in progress
        if ui_state.loading_status == "loading" then
          cancel_object_loading()
        else
          UiObjectSearch.close()
        end
      end,
      ["<Tab>"] = navigate_tab,
      ["<S-Tab>"] = navigate_shift_tab,
      ["/"] = activate_search,
      ["<A-s>"] = focus_settings_panel,
      ["<A-d>"] = focus_database_dropdown,
      ["<A-*>"] = focus_filters_panel,
      ["<A-c>"] = toggle_case_sensitive,
      ["<A-x>"] = toggle_regex,
      ["<A-w>"] = toggle_whole_word,
      ["<A-S>"] = toggle_system,
      ["1"] = toggle_search_names,
      ["2"] = toggle_search_defs,
      ["3"] = toggle_search_meta,
      ["<A-r>"] = refresh_objects,
      ["<A-R>"] = function() UiObjectSearch.reset(false) end,  -- Clear state without reopen
      -- Object type toggles
      ["!"] = toggle_tables,
      ["@"] = toggle_views,
      ["#"] = toggle_procedures,
      ["$"] = toggle_functions,
      ["%"] = toggle_synonyms,
      ["^"] = toggle_schemas,
    }
  end

  -- Setup keymaps for settings panel
  multi_panel:set_panel_keymaps("settings", get_common_keymaps())

  -- Setup keymaps for filters panel
  multi_panel:set_panel_keymaps("filters", get_common_keymaps())

  -- Setup keymaps for results panel (extends common with results-specific keymaps)
  -- Navigation (j/k, arrows) uses default Neovim movement - CursorMoved autocmd syncs selection
  local results_keymaps = get_common_keymaps()
  results_keymaps[common.confirm or "<CR>"] = open_in_buffer
  results_keymaps["<A-o>"] = open_in_buffer
  results_keymaps["<A-e>"] = select_or_exec_in_buffer
  results_keymaps["<A-y>"] = yank_object_name
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
            if multi_panel and multi_panel:is_valid() then
              multi_panel:render_panel("results")
              -- Also update metadata and definition panels
              multi_panel:render_panel("metadata")
              multi_panel:render_panel("definition")
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
    local new_cb = render_settings(multi_panel)
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
        load_objects_for_databases()
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
                load_objects_for_databases()
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
function UiObjectSearch.reset(reopen)
  if reopen == nil then reopen = true end

  -- Clear saved state
  saved_state = nil

  if reopen and multi_panel then
    -- Close and reopen with fresh state
    UiObjectSearch.close()
    vim.schedule(function()
      UiObjectSearch.show({ reset = true })
    end)
  elseif multi_panel then
    -- Just reset current state without reopening
    reset_state(true)
    -- Re-render all panels
    multi_panel:render_all()
    vim.notify("SSNS: Search state cleared", vim.log.levels.INFO)
  else
    vim.notify("SSNS: Saved search state cleared", vim.log.levels.INFO)
  end
end

---Check if object search is open
---@return boolean
function UiObjectSearch.is_open()
  return multi_panel ~= nil
end

return UiObjectSearch
