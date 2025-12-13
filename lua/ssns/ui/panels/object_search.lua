---@class UiObjectSearch
---Database object search UI with 4-panel floating window layout
---Search through tables, views, procedures, functions, synonyms across multiple databases
local UiObjectSearch = {}

local UiFloat = require('ssns.ui.core.float')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')
local UiQuery = require('ssns.ui.core.query')

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
---@field loading_status string "idle"|"loading"|"loaded"|"error"
---@field loading_progress number 0-100 progress percentage
---@field loading_message string Current loading status message
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

---Namespace for search virtual text
local search_virt_ns = vim.api.nvim_create_namespace("ssns_object_search_virt")

---@type ObjectSearchUIState
local ui_state = {
  selected_server = nil,
  selected_databases = {},
  all_databases_selected = false,
  loaded_objects = {},
  loading_status = "idle",
  loading_progress = 0,
  loading_message = "",
  search_term = "",
  search_term_before_edit = "",
  search_editing = false,
  search_names = true,
  search_definitions = true,
  search_metadata = false,
  show_system = false,
  case_sensitive = false,
  use_regex = false,
  whole_word = false,
  filtered_results = {},
  selected_result_idx = 1,
  definitions_cache = {},
}

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
local function reset_state()
  ui_state = {
    selected_server = nil,
    selected_databases = {},
    all_databases_selected = false,
    loaded_objects = {},
    loading_status = "idle",
    loading_progress = 0,
    loading_message = "",
    search_term = "",
    search_term_before_edit = "",
    search_editing = false,
    search_names = true,
    search_definitions = true,
    search_metadata = false,
    show_system = false,
    case_sensitive = false,
    use_regex = false,
    whole_word = false,
    filtered_results = {},
    selected_result_idx = 1,
    definitions_cache = {},
  }
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
local function load_objects_for_databases(callback)
  if not ui_state.selected_server then
    vim.notify("No server selected", vim.log.levels.WARN)
    return
  end

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

  ui_state.loading_status = "loading"
  ui_state.loading_progress = 0
  ui_state.loading_message = "Loading objects..."
  ui_state.loaded_objects = {}

  if multi_panel then
    multi_panel:render_panel("results")
  end

  -- Process databases in sequence using vim.schedule to avoid blocking
  local db_idx = 1
  local total_dbs = #databases

  local function process_next_database()
    if db_idx > total_dbs then
      -- Done loading
      ui_state.loading_status = "loaded"
      ui_state.loading_progress = 100
      ui_state.loading_message = string.format("Loaded %d objects", #ui_state.loaded_objects)

      -- Apply initial filter (always call _apply_search to apply system filter)
      UiObjectSearch._apply_search(ui_state.search_term)

      if multi_panel then
        multi_panel:render_all()
      end

      if callback then callback() end
      return
    end

    local db = databases[db_idx]
    ui_state.loading_message = string.format("Loading %s (%d/%d)...", db.db_name, db_idx, total_dbs)
    ui_state.loading_progress = math.floor((db_idx - 1) / total_dbs * 100)

    if multi_panel then
      multi_panel:render_panel("results")
    end

    -- Bulk load objects for this database
    vim.schedule(function()
      local definitions_map = {}
      local metadata_map = {}

      -- Load all object types
      local ok, err = pcall(function()
        -- First, ensure schemas are loaded (required for schema-based DBs like SQL Server)
        -- This populates db.schemas so bulk load can distribute objects to them
        db:load()

        -- Now bulk load all object types (these distribute to existing schemas)
        db:load_all_tables_bulk()
        db:load_all_views_bulk()
        db:load_all_procedures_bulk()
        db:load_all_functions_bulk()
        if db.load_all_synonyms_bulk then
          db:load_all_synonyms_bulk()
        end

        -- Bulk load definitions for all object types (tables, views, procedures, functions)
        if db.load_all_definitions_bulk then
          definitions_map = db:load_all_definitions_bulk()
        end

        -- Bulk load metadata (columns for tables/views, parameters for procedures/functions)
        if db.load_all_metadata_bulk then
          metadata_map = db:load_all_metadata_bulk()
        end
      end)

      if not ok then
        vim.notify(string.format("Error loading %s: %s", db.db_name, err), vim.log.levels.WARN)
      end

      -- Flatten objects from this database
      local db_objects = flatten_database_objects(db, server)
      for _, obj in ipairs(db_objects) do
        -- Apply bulk-loaded definition and metadata if available
        -- Skip schemas as they don't have definitions or metadata
        if obj.object_type ~= "schema" then
          local key = string.format("%s.%s.%s", obj.schema_name or "dbo", obj.object_type, obj.name)

          -- Apply definition
          if definitions_map[key] then
            obj.definition = definitions_map[key]
            obj.definition_loaded = true
            ui_state.definitions_cache[obj.unique_id] = definitions_map[key]
          end

          -- Apply metadata (columns/parameters as searchable text)
          if metadata_map[key] then
            obj.metadata_text = metadata_map[key]
            obj.metadata_loaded = true
          end
        end
        table.insert(ui_state.loaded_objects, obj)
      end

      -- Move to next database
      db_idx = db_idx + 1
      vim.schedule(process_next_database)
    end)
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

  -- Load from object
  local obj = searchable.object
  if obj and obj.get_definition then
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
---@return boolean matched
---@return string? matched_text
local function text_matches_pattern(text, pattern, regex)
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
      search_for = pattern:lower()
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

---Apply search filter to loaded objects
---@param pattern string Search pattern
function UiObjectSearch._apply_search(pattern)
  if not pattern or pattern == "" then
    -- No search - show all objects (limited)
    ui_state.filtered_results = {}
    local max_results = 500
    local count = 0
    for _, obj in ipairs(ui_state.loaded_objects) do
      if count >= max_results then break end
      -- Filter system objects unless show_system is enabled
      if ui_state.show_system or not is_system_object(obj) then
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
    return
  end

  local filtered = {}
  local regex = nil

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

  local max_results = 500

  for _, searchable in ipairs(ui_state.loaded_objects) do
    if #filtered >= max_results then break end

    -- Filter system objects unless show_system is enabled
    if not ui_state.show_system and is_system_object(searchable) then
      goto continue
    end

    local match_details = {}
    local matched_name = false
    local matched_def = false
    local matched_meta = false

    -- Search in name
    if ui_state.search_names then
      local matched, matched_text = text_matches_pattern(searchable.name, pattern, regex)
      if matched then
        matched_name = true
        table.insert(match_details, { field = "name", matched_text = matched_text or "" })
      end
    end

    -- Search in definition (lazy load)
    if ui_state.search_definitions and not matched_name then
      local definition = load_definition(searchable)
      if definition then
        local matched, matched_text = text_matches_pattern(definition, pattern, regex)
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
        local matched, matched_text = text_matches_pattern(metadata, pattern, regex)
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

    ::continue::
  end

  -- Sort by priority (name matches first)
  table.sort(filtered, function(a, b)
    if a.sort_priority ~= b.sort_priority then
      return a.sort_priority < b.sort_priority
    end
    return a.display_name < b.display_name
  end)

  ui_state.filtered_results = filtered

  -- Reset selection if invalid
  if ui_state.selected_result_idx > #ui_state.filtered_results then
    ui_state.selected_result_idx = math.max(1, #ui_state.filtered_results)
  end
end

-- ============================================================================
-- Render Functions
-- ============================================================================

---Build search settings hint line
---@return string line
---@return table[] highlights
local function build_search_settings_line()
  local case_state = ui_state.case_sensitive and "On" or "Off"
  local regex_state = ui_state.use_regex and "On" or "Off"
  local word_state = ui_state.whole_word and "On" or "Off"

  local line = string.format(" A-c:%s | A-r:%s | A-w:%s", case_state, regex_state, word_state)
  local highlights = {{0, 0, #line, "Comment"}}

  return line, highlights
end

---Build search context hint line
---@return string line
---@return table[] highlights
local function build_search_context_line()
  local names_state = ui_state.search_names and "On" or "Off"
  local defs_state = ui_state.search_definitions and "On" or "Off"
  local meta_state = ui_state.search_metadata and "On" or "Off"
  local sys_state = ui_state.show_system and "On" or "Off"

  local line = string.format(" A-1 Names:%s | A-2 Defs:%s | A-3 Meta:%s | A-s Sys:%s", names_state, defs_state, meta_state, sys_state)
  local highlights = {{0, 0, #line, "Comment"}}

  return line, highlights
end

---Render the search panel
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

---Render the results panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_results(state)
  local lines = {}
  local highlights = {}

  -- Header: Server and database info
  table.insert(lines, "")

  if ui_state.selected_server then
    local db_count = 0
    for _ in pairs(ui_state.selected_databases) do
      db_count = db_count + 1
    end

    local db_names = {}
    for name, _ in pairs(ui_state.selected_databases) do
      table.insert(db_names, name)
    end

    local db_display = db_count > 2
      and string.format("%s (+%d)", db_names[1], db_count - 1)
      or table.concat(db_names, ", ")

    table.insert(lines, string.format(" Server: %s", ui_state.selected_server.name))
    table.insert(highlights, {1, 0, -1, "SsnsServer"})

    table.insert(lines, string.format(" Databases: %s", db_display))
    table.insert(highlights, {2, 0, -1, "SsnsDatabase"})

    table.insert(lines, string.format(" Objects: %d | Results: %d",
      #ui_state.loaded_objects, #ui_state.filtered_results))
    table.insert(highlights, {3, 0, -1, "SsnsUiHint"})
  else
    table.insert(lines, " No server selected")
    table.insert(highlights, {1, 0, -1, "Comment"})
    table.insert(lines, " Press 's' to select a server")
    table.insert(highlights, {2, 0, -1, "Comment"})
  end

  table.insert(lines, "")

  -- Loading indicator
  if ui_state.loading_status == "loading" then
    local progress_bar = string.rep("█", math.floor(ui_state.loading_progress / 10))
    progress_bar = progress_bar .. string.rep("░", 10 - #progress_bar)
    table.insert(lines, string.format(" [%s] %d%%", progress_bar, ui_state.loading_progress))
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiHint"})
    table.insert(lines, " " .. ui_state.loading_message)
    table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
    return lines, highlights
  end

  -- Results list
  local header_lines = #lines

  for i, result in ipairs(ui_state.filtered_results) do
    local prefix = i == ui_state.selected_result_idx and " ▶ " or "   "
    local icon = get_object_icon(result.searchable.object_type)
    local badge = result.match_type ~= "none" and string.format("[%s]", result.match_type) or ""

    local line = string.format("%s%s %s.%s %s",
      prefix,
      icon,
      result.searchable.database_name,
      result.display_name,
      badge
    )
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == ui_state.selected_result_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
    end

    -- Highlight icon based on type
    local icon_col = i == ui_state.selected_result_idx and 4 or 3
    local type_hl = "Ssns" .. result.searchable.object_type:sub(1, 1):upper() .. result.searchable.object_type:sub(2)
    table.insert(highlights, {line_idx, icon_col, icon_col + 1, type_hl})
  end

  if #ui_state.filtered_results == 0 then
    if #ui_state.loaded_objects == 0 then
      table.insert(lines, "   Press 'd' to select databases and load objects")
    else
      table.insert(lines, "   (No matches)")
    end
    table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
  end

  return lines, highlights
end

---Render the metadata panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_metadata(state)
  local lines = {}
  local highlights = {}

  if ui_state.selected_result_idx < 1 or ui_state.selected_result_idx > #ui_state.filtered_results then
    table.insert(lines, "")
    table.insert(lines, " Select an object to view metadata")
    table.insert(highlights, {1, 0, -1, "Comment"})
    return lines, highlights
  end

  local result = ui_state.filtered_results[ui_state.selected_result_idx]
  local searchable = result.searchable
  local obj = searchable.object

  -- Header
  table.insert(lines, "")
  table.insert(lines, string.format(" %s: %s", searchable.object_type:upper(), searchable.name))
  table.insert(highlights, {1, 0, -1, "SsnsUiTitle"})

  table.insert(lines, string.format(" Schema: %s", searchable.schema_name or "N/A"))
  table.insert(lines, string.format(" Database: %s", searchable.database_name))
  table.insert(lines, "")

  -- Object-specific metadata
  if searchable.object_type == "table" or searchable.object_type == "view" then
    -- Show columns
    table.insert(lines, " Columns:")
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiTitle"})

    if obj and obj.get_columns then
      local ok, columns = pcall(function()
        return obj:get_columns({ skip_load = true })
      end)

      if ok and columns and #columns > 0 then
        for _, col in ipairs(columns) do
          local nullable = col.nullable and "NULL" or "NOT NULL"
          local line = string.format("   %s (%s) %s", col.name, col.data_type or "?", nullable)
          table.insert(lines, line)
        end
      else
        table.insert(lines, "   (Load object to see columns)")
        table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
      end
    end
  elseif searchable.object_type == "procedure" or searchable.object_type == "function" then
    -- Show parameters
    table.insert(lines, " Parameters:")
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiTitle"})

    if obj and obj.get_parameters then
      local ok, params = pcall(function()
        return obj:get_parameters({ skip_load = true })
      end)

      if ok and params and #params > 0 then
        for _, param in ipairs(params) do
          local direction = param.is_output and "OUT" or "IN"
          local line = string.format("   %s %s (%s)", direction, param.name, param.data_type or "?")
          table.insert(lines, line)
        end
      else
        table.insert(lines, "   (Load object to see parameters)")
        table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
      end
    end
  elseif searchable.object_type == "synonym" then
    -- Show synonym target
    table.insert(lines, " Target:")
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiTitle"})

    if obj and obj.base_object_name then
      table.insert(lines, "   " .. obj.base_object_name)
    else
      table.insert(lines, "   (Unknown)")
      table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
    end
  end

  return lines, highlights
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
  table.insert(lines, string.format("-- Database: %s.%s",
    searchable.database_name, searchable.schema_name or ""))
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

---Update virtual text settings during search editing
local function update_search_settings_virt_text()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf or not vim.api.nvim_buf_is_valid(search_buf) then return end

  vim.api.nvim_buf_clear_namespace(search_buf, search_virt_ns, 0, -1)

  local settings_line, _ = build_search_settings_line()
  local context_line, _ = build_search_context_line()

  vim.api.nvim_buf_set_extmark(search_buf, search_virt_ns, 0, 0, {
    virt_lines = {
      {{settings_line, "Comment"}},
      {{context_line, "Comment"}},
    },
    virt_lines_above = false,
  })
end

---Finalize search exit
local function finalize_search_exit()
  ui_state.search_editing = false

  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    vim.api.nvim_buf_clear_namespace(search_buf, search_virt_ns, 0, -1)
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

---Cancel search
local function cancel_search()
  ui_state.search_term = ui_state.search_term_before_edit
  UiObjectSearch._apply_search(ui_state.search_term)
  vim.cmd('stopinsert')
end

---Commit search
local function commit_search()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    ui_state.search_term = (lines[1] or ""):gsub("^%s+", "")
  end
  vim.cmd('stopinsert')
end

---Toggle functions for search settings
local function toggle_case_sensitive()
  ui_state.case_sensitive = not ui_state.case_sensitive
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_regex_mode()
  ui_state.use_regex = not ui_state.use_regex
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_whole_word()
  ui_state.whole_word = not ui_state.whole_word
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_search_names()
  ui_state.search_names = not ui_state.search_names
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_search_definitions()
  ui_state.search_definitions = not ui_state.search_definitions
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_search_metadata()
  ui_state.search_metadata = not ui_state.search_metadata
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

local function toggle_show_system()
  ui_state.show_system = not ui_state.show_system
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    local text = (lines[1] or ""):gsub("^%s+", "")
    UiObjectSearch._apply_search(text)
  end
  update_search_settings_virt_text()
  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
  end
end

---Setup search autocmds
local function setup_search_autocmds()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
  end

  search_augroup = vim.api.nvim_create_augroup("SSNSObjectSearch", { clear = true })

  -- Live filtering on text change
  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
    group = search_augroup,
    buffer = search_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
      local text = (lines[1] or ""):gsub("^%s+", "")
      UiObjectSearch._apply_search(text)
      if multi_panel then
        multi_panel:render_panel("results")
        multi_panel:render_panel("metadata")
        multi_panel:render_panel("definition")
      end
    end,
  })

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

  -- Search settings toggles
  KeymapManager.set(search_buf, 'i', '<A-c>', toggle_case_sensitive, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-r>', toggle_regex_mode, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-w>', toggle_whole_word, { nowait = true })

  -- Search context toggles
  KeymapManager.set(search_buf, 'i', '<A-1>', toggle_search_names, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-2>', toggle_search_definitions, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-3>', toggle_search_metadata, { nowait = true })
  KeymapManager.set(search_buf, 'i', '<A-s>', toggle_show_system, { nowait = true })

  KeymapManager.setup_auto_restore(search_buf)
end

---Activate search mode
local function activate_search()
  if not multi_panel then return end

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
  update_search_settings_virt_text()
end

-- ============================================================================
-- Navigation Functions
-- ============================================================================

---Navigate in results panel
---@param direction number 1 for down, -1 for up
local function navigate_results(direction)
  if #ui_state.filtered_results == 0 then return end

  ui_state.selected_result_idx = ui_state.selected_result_idx + direction

  if ui_state.selected_result_idx < 1 then
    ui_state.selected_result_idx = #ui_state.filtered_results
  elseif ui_state.selected_result_idx > #ui_state.filtered_results then
    ui_state.selected_result_idx = 1
  end

  if multi_panel then
    multi_panel:render_panel("results")
    multi_panel:render_panel("metadata")
    multi_panel:render_panel("definition")
    multi_panel:set_cursor("results", ui_state.selected_result_idx + 5, 0)
  end
end

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

-- ============================================================================
-- Server/Database Selection
-- ============================================================================

-- Forward declaration for show_database_picker (called from show_server_picker)
local show_database_picker

---Show server picker
local function show_server_picker()
  local UiFloatInteractive = require('ssns.ui.base.float_interactive')
  local ContentBuilder = require('ssns.ui.core.content_builder')
  local Connections = require('ssns.connections')
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

  -- Saved connections
  local saved_connections = Connections.load()
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
    width = 50,
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

      -- Connect if not connected
      local server = selected.server
      if not server then
        server = Cache.find_server(selected.name)
        if not server and selected.connection_config then
          server = Cache.find_or_create_server(selected.name, selected.connection_config)
        end
      end

      if server and not server:is_connected() then
        vim.notify("Connecting to " .. selected.name .. "...", vim.log.levels.INFO)
        local ok, err = server:connect()
        if not ok then
          vim.notify("Failed to connect: " .. (err or "Unknown"), vim.log.levels.ERROR)
          return
        end
      end

      if server then
        ui_state.selected_server = server
        -- Clear databases and reload
        ui_state.selected_databases = {}
        ui_state.all_databases_selected = false
        ui_state.loaded_objects = {}
        ui_state.filtered_results = {}

        -- Auto-show database picker
        vim.schedule(function()
          show_database_picker()
        end)
      end
    end,
  })
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

  -- Load databases if needed
  if not server.databases or #server.databases == 0 then
    server:load()
  end

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
    width = 50,
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
      ["a"] = function(state)
        state.data.all_selected = not state.data.all_selected
        if state.data.all_selected then
          state.data.selection = {}
        end
        UiFloatInteractive.render(state)
      end,
    },
  })
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
  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    search_augroup = nil
  end

  if multi_panel then
    multi_panel:close()
    multi_panel = nil
  end

  reset_state()
end

---Show the object search UI
---@param options table? Options {server?: ServerClass, database?: DbClass}
function UiObjectSearch.show(options)
  options = options or {}

  -- Close existing
  UiObjectSearch.close()

  -- Initialize state
  reset_state()

  -- Get keymaps from config
  local km = KeymapManager.get_group("object_search")
  local common = KeymapManager.get_group("common")

  -- Create multi-panel window
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          -- Left column: search + results
          split = "vertical",
          ratio = 0.40,
          children = {
            {
              name = "search",
              title = "Search",
              ratio = 0.10,
              min_height = 2,
              focusable = false,
              cursorline = false,
              on_render = render_search,
            },
            {
              name = "results",
              title = "Results",
              ratio = 0.90,
              focusable = true,
              cursorline = true,
              on_render = render_results,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("results", "Results ●")
                  multi_panel:update_panel_title("metadata", "Metadata")
                  multi_panel:update_panel_title("definition", "Definition")
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
              ratio = 0.25,
              focusable = true,
              cursorline = false,
              on_render = render_metadata,
              on_focus = function()
                if multi_panel then
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
                if multi_panel then
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
    total_width_ratio = 0.80,
    total_height_ratio = 0.80,
    footer = " /=Search | s=Server | d=Databases | r=Refresh | o=Open | y=Yank | q=Close ",
    initial_focus = "results",
    augroup_name = "SSNSObjectSearch",
    on_close = function()
      if search_augroup then
        pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
        search_augroup = nil
      end
      multi_panel = nil
      reset_state()
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Setup keymaps for results panel
  multi_panel:set_panel_keymaps("results", {
    [common.close or "q"] = function() UiObjectSearch.close() end,
    [common.cancel or "<Esc>"] = function() UiObjectSearch.close() end,
    [common.nav_down or "j"] = function() navigate_results(1) end,
    [common.nav_up or "k"] = function() navigate_results(-1) end,
    ["<Down>"] = function() navigate_results(1) end,
    ["<Up>"] = function() navigate_results(-1) end,
    [common.confirm or "<CR>"] = open_in_buffer,
    ["o"] = open_in_buffer,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    ["/"] = activate_search,
    ["s"] = show_server_picker,
    ["d"] = show_database_picker,
    ["r"] = refresh_objects,
    ["y"] = yank_object_name,
  })

  -- Setup keymaps for metadata panel
  multi_panel:set_panel_keymaps("metadata", {
    [common.close or "q"] = function() UiObjectSearch.close() end,
    [common.cancel or "<Esc>"] = function() UiObjectSearch.close() end,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    ["/"] = activate_search,
    ["s"] = show_server_picker,
    ["d"] = show_database_picker,
    ["r"] = refresh_objects,
  })

  -- Setup keymaps for definition panel
  multi_panel:set_panel_keymaps("definition", {
    [common.close or "q"] = function() UiObjectSearch.close() end,
    [common.cancel or "<Esc>"] = function() UiObjectSearch.close() end,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    ["/"] = activate_search,
    ["s"] = show_server_picker,
    ["d"] = show_database_picker,
    ["r"] = refresh_objects,
  })

  -- Mark initial focus
  multi_panel:update_panel_title("results", "Results ●")

  -- Handle initial context
  if options.server then
    ui_state.selected_server = options.server

    if options.database then
      ui_state.selected_databases[options.database.db_name] = options.database
      -- Start loading objects
      vim.schedule(function()
        load_objects_for_databases()
      end)
    else
      -- Show database picker
      vim.schedule(function()
        show_database_picker()
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
                load_objects_for_databases()
              end)
              return
            end
          end

          -- Have server but no database - show picker
          vim.schedule(function()
            show_database_picker()
          end)
          return
        end
      end
    end

    -- No context - show server picker
    vim.schedule(function()
      show_server_picker()
    end)
  end
end

return UiObjectSearch
