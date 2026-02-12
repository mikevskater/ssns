---@class ObjectSearchRender
---Panel rendering functions for the object search module
local M = {}

local State = require('nvim-ssns.ui.panels.object_search.state')
local Helpers = require('nvim-ssns.ui.panels.object_search.helpers')
local ContentBuilder = require('nvim-float.content')
local Cache = require('nvim-ssns.cache')

---Forward reference for load_definition (injected by init.lua)
---@type fun(searchable: SearchableObject): string?
local load_definition_fn = nil

---Inject the load_definition function (called by init.lua)
---@param fn fun(searchable: SearchableObject): string?
function M.set_load_definition_fn(fn)
  load_definition_fn = fn
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Get selected search targets as values array
---@return string[]
local function get_search_targets_values()
  local ui_state = State.get_ui_state()
  local values = {}
  if ui_state.search_names then table.insert(values, "names") end
  if ui_state.search_definitions then table.insert(values, "defs") end
  if ui_state.search_metadata then table.insert(values, "meta") end
  return values
end

---Get selected object types as values array
---@return string[]
local function get_object_types_values()
  local ui_state = State.get_ui_state()
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
function M.invalidate_visible_count_cache()
  local ui_state = State.get_ui_state()
  ui_state._visible_count_cache = nil
end

---Calculate visible object count based on current filters (cached)
---@return number
local function get_visible_object_count()
  local ui_state = State.get_ui_state()

  -- Return cached value if available
  if ui_state._visible_count_cache ~= nil then
    return ui_state._visible_count_cache
  end

  -- Calculate and cache
  local count = 0
  for _, obj in ipairs(ui_state.loaded_objects) do
    -- Check system filter
    if ui_state.show_system or not Helpers.is_system_object(obj) then
      -- Check object type filter
      if Helpers.should_show_object_type(obj) then
        count = count + 1
      end
    end
  end

  ui_state._visible_count_cache = count
  return count
end

---Get object type style name for ContentBuilder
---@param object_type string
---@return string style
local function get_object_style(object_type)
  local styles = {
    table = "sql_table",
    view = "sql_view",
    procedure = "sql_procedure",
    ["function"] = "func",
    synonym = "muted",
    schema = "sql_schema",
  }
  return styles[object_type] or "normal"
end

---Build spans with match positions highlighted
---@param text string The text to highlight
---@param positions MatchPosition[] Match positions (1-indexed, from search)
---@param base_style string Default style for non-matched text
---@param match_style string Style for matched text (default: "search_match")
---@return table[] spans Array of {text, style} for ContentBuilder
local function build_highlighted_spans(text, positions, base_style, match_style)
  match_style = match_style or "search_match"

  if not positions or #positions == 0 then
    return {{ text = text, style = base_style }}
  end

  local spans = {}
  local last_end = 1

  -- Sort by start position (in case they're not sorted)
  local sorted_positions = {}
  for _, pos in ipairs(positions) do
    table.insert(sorted_positions, pos)
  end
  table.sort(sorted_positions, function(a, b) return a.start < b.start end)

  for _, pos in ipairs(sorted_positions) do
    -- Add text before this match
    if pos.start > last_end then
      local before_text = text:sub(last_end, pos.start - 1)
      if #before_text > 0 then
        table.insert(spans, { text = before_text, style = base_style })
      end
    end

    -- Add the matched text
    local match_end = pos.end_ or (pos.start + #(pos.text or "") - 1)
    local matched_text = text:sub(pos.start, match_end)
    if #matched_text > 0 then
      table.insert(spans, { text = matched_text, style = match_style })
    end

    last_end = match_end + 1
  end

  -- Add remaining text after last match
  if last_end <= #text then
    local after_text = text:sub(last_end)
    if #after_text > 0 then
      table.insert(spans, { text = after_text, style = base_style })
    end
  end

  -- Handle edge case: if no spans were added, return the original text
  if #spans == 0 then
    return {{ text = text, style = base_style }}
  end

  return spans
end

---Find matches in a text segment for metadata items (re-search in main thread)
---@param segment_text string The text segment (e.g., column name)
---@return MatchPosition[] positions Match positions within the segment
local function find_matches_in_segment(segment_text)
  local ui_state = State.get_ui_state()
  local pattern = ui_state.search_term

  if not pattern or pattern == "" or not segment_text or segment_text == "" then
    return {}
  end

  local search_text = ui_state.case_sensitive and segment_text or segment_text:lower()
  local search_pattern = ui_state.case_sensitive and pattern or pattern:lower()

  local positions = {}
  local pos = 1
  local max_positions = 20  -- Limit for safety

  while pos <= #search_text and #positions < max_positions do
    local match_start, match_end

    if ui_state.use_regex then
      -- Use Lua pattern matching
      match_start, match_end = search_text:find(search_pattern, pos)
    else
      -- Plain text search
      match_start, match_end = search_text:find(search_pattern, pos, true)
      if match_start then
        match_end = match_start + #search_pattern - 1
      end
    end

    if not match_start then break end

    -- Check whole word if needed
    local is_valid = true
    if ui_state.whole_word then
      is_valid = Helpers.is_whole_word_match(search_text, match_start, match_end)
    end

    if is_valid then
      table.insert(positions, {
        start = match_start,
        end_ = match_end,
        text = segment_text:sub(match_start, match_end),
      })
    end

    pos = match_start + 1
  end

  return positions
end

-- ============================================================================
-- Settings Panel Helpers
-- ============================================================================

---Build server dropdown options from cache and connections
---Uses cached saved connections (loaded async on panel open)
---@return DropdownOption[] options
local function get_server_options()
  local ui_state = State.get_ui_state()
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
  local Config = require('nvim-ssns.config')
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
  local ui_state = State.get_ui_state()
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
    if ui_state.show_system or not State.SYSTEM_DATABASES[db.db_name] then
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
  local ui_state = State.get_ui_state()
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
  local ui_state = State.get_ui_state()
  local values = {}
  if ui_state.case_sensitive then table.insert(values, "case") end
  if ui_state.use_regex then table.insert(values, "regex") end
  if ui_state.whole_word then table.insert(values, "word") end
  if ui_state.show_system then table.insert(values, "system") end
  return values
end

-- ============================================================================
-- Panel Render Functions
-- ============================================================================

---Render the search panel (now just shows search input)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_search(state)
  local ui_state = State.get_ui_state()
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
    table.insert(highlights, {0, 0, -1, "NvimFloatHint"})
  end

  return lines, highlights
end

---Render the filters panel (filter toggles + status/counts)
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_filters(state)
  local ui_state = State.get_ui_state()

  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["filters"] and state.panels["filters"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Search targets multi-dropdown (embedded, what to search in)
  cb:embedded_multi_dropdown("search_targets", {
    label = "Search In ",
    options = {
      { value = "names", label = "Names {1}" },
      { value = "defs", label = "Definitions {2}" },
      { value = "meta", label = "Metadata {3}" },
    },
    selected = get_search_targets_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 40,
  })

  -- Row 2: Object types multi-dropdown (embedded, what types to show)
  cb:embedded_multi_dropdown("object_types", {
    label = "Types     ",
    options = {
      { value = "table", label = "T Tables {!}" },
      { value = "view", label = "V Views {@}" },
      { value = "procedure", label = "P Procs {#}" },
      { value = "function", label = "F Funcs {$}" },
      { value = "synonym", label = "S Synonyms {%}" },
      { value = "schema", label = "σ Schemas {^}" },
    },
    selected = get_object_types_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 40,
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

---Render the settings panel with embedded container dropdowns
---@param state MultiPanelState
---@return ContentBuilder cb
function M.render_settings(state)
  local ui_state = State.get_ui_state()

  -- Get panel width for responsive input sizing
  local panel_width = state.panels and state.panels["settings"] and state.panels["settings"].float._win_width
  local cb = ContentBuilder.new()
  if panel_width then
    cb:set_max_width(panel_width)
  end

  -- Row 1: Server dropdown (embedded)
  cb:embedded_dropdown("server", {
    label = "Server    ",
    options = get_server_options(),
    selected = ui_state.selected_server and ui_state.selected_server.name or "",
    placeholder = "(select server)",
    width = 40,
  })

  -- Row 2: Database multi-dropdown (embedded, show loading state)
  local db_placeholder = "(select databases)"
  local db_options = {}

  if ui_state.server_loading then
    local spinner_char = State.get_loading_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end
    db_placeholder = spinner_char .. " Loading databases..."
  elseif not ui_state.selected_server then
    db_placeholder = "(select server first)"
  else
    db_options = get_database_options()
    if #db_options == 0 then
      db_placeholder = "(no databases found)"
    end
  end

  cb:embedded_multi_dropdown("databases", {
    label = "Databases ",
    options = db_options,
    selected = get_selected_db_names(),
    display_mode = "count",
    placeholder = db_placeholder,
    width = 40,
  })

  -- Row 3: Search options multi-dropdown (embedded, list mode)
  cb:embedded_multi_dropdown("search_options", {
    label = "Options   ",
    options = {
      { value = "case", label = "Case {c}" },
      { value = "regex", label = "Regex {x}" },
      { value = "word", label = "Word {w}" },
      { value = "system", label = "Sys Objs {S}" },
    },
    selected = get_search_options_values(),
    display_mode = "list",
    placeholder = "(none)",
    width = 40,
  })

  return cb
end

---Render the results panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
function M.render_results(state)
  local ui_state = State.get_ui_state()
  local cb = ContentBuilder.new()

  -- Show loading status header when loading (but continue to show results below)
  if ui_state.loading_status == "loading" then
    local spinner_char = State.get_loading_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end

    -- Get runtime from loading spinner (not search spinner)
    local runtime = "..."
    -- We need access to the loading spinner runtime - use a simple time counter
    -- The actual spinner has runtime, but we access it through State

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "success" },
      { text = " ", style = "normal" },
      { text = ui_state.loading_message, style = "emphasis" },
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
  if State.get_search_in_progress() then
    local spinner_char = State.get_search_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end
    local elapsed = State.get_search_elapsed_time()
    local total = State.get_search_total_objects()
    local progress = State.get_search_progress()
    local searched = math.floor(total * progress / 100)

    cb:spans({
      { text = " ", style = "normal" },
      { text = spinner_char, style = "warning" },
      { text = " Filtering: ", style = "emphasis" },
      { text = tostring(searched), style = "value" },
      { text = "/", style = "muted" },
      { text = tostring(total), style = "value" },
      { text = string.format(" (%d%%)", progress), style = "muted" },
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
    local icon = Helpers.get_object_icon(result.searchable.object_type)
    local obj_style = get_object_style(result.searchable.object_type)
    local badge = result.match_type ~= "none" and string.format(" [%s]", result.match_type) or ""

    local spans = {
      { text = prefix, style = is_selected and "highlight" or "normal" },
      { text = icon .. " ", style = is_selected and "strong" or obj_style },
    }

    -- Add database_name with highlights (skip if selected)
    if not is_selected then
      local db_positions = find_matches_in_segment(result.searchable.database_name)
      if #db_positions > 0 then
        local db_spans = build_highlighted_spans(result.searchable.database_name, db_positions, "sql_database", "search_match")
        for _, span in ipairs(db_spans) do
          table.insert(spans, span)
        end
      else
        table.insert(spans, { text = result.searchable.database_name, style = "sql_database" })
      end
    else
      table.insert(spans, { text = result.searchable.database_name, style = "strong" })
    end

    table.insert(spans, { text = ".", style = is_selected and "strong" or "muted" })

    -- Build display_name with highlights (skip if selected - already highlighted)
    -- Re-search within display_name since it includes schema prefix that shifts positions
    if not is_selected then
      local name_positions = find_matches_in_segment(result.display_name)
      if #name_positions > 0 then
        local name_spans = build_highlighted_spans(result.display_name, name_positions, obj_style, "search_match")
        for _, span in ipairs(name_spans) do
          table.insert(spans, span)
        end
      else
        table.insert(spans, { text = result.display_name, style = obj_style })
      end
    else
      table.insert(spans, { text = result.display_name, style = "strong" })
    end

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
function M.render_metadata(state)
  local ui_state = State.get_ui_state()
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

  -- Header with object name (highlight matches)
  local name_spans = {
    { text = " ", style = "normal" },
    { text = searchable.object_type:upper(), style = "muted" },
    { text = ": ", style = "muted" },
  }
  local name_positions = find_matches_in_segment(searchable.name)
  if #name_positions > 0 then
    local highlighted = build_highlighted_spans(searchable.name, name_positions, obj_style, "search_match")
    for _, span in ipairs(highlighted) do
      table.insert(name_spans, span)
    end
  else
    table.insert(name_spans, { text = searchable.name, style = obj_style })
  end
  cb:spans(name_spans)

  -- Schema line (highlight matches)
  local schema_text = searchable.schema_name or "N/A"
  local schema_spans = {
    { text = " Schema: ", style = "label" },
  }
  local schema_positions = find_matches_in_segment(schema_text)
  if #schema_positions > 0 then
    local highlighted = build_highlighted_spans(schema_text, schema_positions, "sql_schema", "search_match")
    for _, span in ipairs(highlighted) do
      table.insert(schema_spans, span)
    end
  else
    table.insert(schema_spans, { text = schema_text, style = "sql_schema" })
  end
  cb:spans(schema_spans)

  -- Database line (highlight matches)
  local db_spans = {
    { text = " Database: ", style = "label" },
  }
  local db_positions = find_matches_in_segment(searchable.database_name)
  if #db_positions > 0 then
    local highlighted = build_highlighted_spans(searchable.database_name, db_positions, "sql_database", "search_match")
    for _, span in ipairs(highlighted) do
      table.insert(db_spans, span)
    end
  else
    table.insert(db_spans, { text = searchable.database_name, style = "sql_database" })
  end
  cb:spans(db_spans)

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

          -- Check for search matches in column name
          local name_positions = find_matches_in_segment(col.name)
          local spans = {
            { text = "   ", style = "normal" },
          }

          -- Add column name with or without highlighting
          if #name_positions > 0 then
            local name_spans = build_highlighted_spans(col.name, name_positions, "sql_column", "search_match")
            for _, span in ipairs(name_spans) do
              table.insert(spans, span)
            end
          else
            table.insert(spans, { text = col.name, style = "sql_column" })
          end

          table.insert(spans, { text = " (", style = "muted" })
          table.insert(spans, { text = col.data_type or "?", style = "keyword" })
          table.insert(spans, { text = ") ", style = "muted" })
          table.insert(spans, { text = nullable_text, style = nullable_style })

          cb:spans(spans)
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

          -- Check for search matches in parameter name
          local name_positions = find_matches_in_segment(param.name)
          local spans = {
            { text = "   ", style = "normal" },
            { text = direction, style = dir_style },
            { text = " ", style = "normal" },
          }

          -- Add param name with or without highlighting
          if #name_positions > 0 then
            local name_spans = build_highlighted_spans(param.name, name_positions, "sql_parameter", "search_match")
            for _, span in ipairs(name_spans) do
              table.insert(spans, span)
            end
          else
            table.insert(spans, { text = param.name, style = "sql_parameter" })
          end

          table.insert(spans, { text = " (", style = "muted" })
          table.insert(spans, { text = param.data_type or "?", style = "keyword" })
          table.insert(spans, { text = ")", style = "muted" })

          cb:spans(spans)
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
        { text = obj.base_object_name, style = "sql_table" },
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
function M.render_definition(state)
  local ui_state = State.get_ui_state()
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
  local definition = nil
  if load_definition_fn then
    definition = load_definition_fn(searchable)
  end

  -- Get definition positions from match_details for overlay highlighting
  local def_positions = {}
  for _, detail in ipairs(result.match_details or {}) do
    if detail.field == "definition" and detail.positions and #detail.positions > 0 then
      def_positions = detail.positions
      break
    end
  end

  -- Track header line count for position offset
  local header_lines = #lines

  if definition then
    local def_lines = vim.split(definition, "\n")

    -- Track current character position in the full definition text
    local current_pos = 1

    for line_idx, def_line in ipairs(def_lines) do
      table.insert(lines, def_line)

      -- Calculate line boundaries (1-indexed positions in full text)
      local line_start = current_pos
      local line_end = current_pos + #def_line - 1

      -- Find positions overlapping this line
      for _, pos in ipairs(def_positions) do
        if pos.end_ >= line_start and pos.start <= line_end then
          -- Calculate column positions (0-indexed for nvim API)
          local col_start = math.max(0, pos.start - line_start)
          local col_end = math.min(#def_line, pos.end_ - line_start + 1)
          local line_0idx = header_lines + line_idx - 1  -- 0-indexed line number

          table.insert(highlights, {line_0idx, col_start, col_end, "SsnsSearchMatch"})
        end
      end

      -- Move position past this line plus newline character
      current_pos = line_end + 2
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
-- Exports for external access
-- ============================================================================

-- Export helper functions that may be needed elsewhere
M.get_search_targets_values = get_search_targets_values
M.get_object_types_values = get_object_types_values
M.get_visible_object_count = get_visible_object_count
M.get_server_options = get_server_options
M.get_database_options = get_database_options
M.get_selected_db_names = get_selected_db_names
M.get_search_options_values = get_search_options_values

return M
