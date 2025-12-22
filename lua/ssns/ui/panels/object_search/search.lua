---@class ObjectSearchSearch
---Search and filter functions for the object search module
local M = {}

local State = require('ssns.ui.panels.object_search.state')
local Helpers = require('ssns.ui.panels.object_search.helpers')
local Render = require('ssns.ui.panels.object_search.render')
local Cancellation = require('ssns.async.cancellation')
local Thread = require('ssns.async.thread')

---Forward reference for load_definition (injected by init.lua)
---@type fun(searchable: SearchableObject): string?
local load_definition_fn = nil

---Forward reference for load_metadata_text (injected by init.lua)
---@type fun(searchable: SearchableObject): string?
local load_metadata_text_fn = nil

---Inject the load_definition function (called by init.lua)
---@param fn fun(searchable: SearchableObject): string?
function M.set_load_definition_fn(fn)
  load_definition_fn = fn
end

---Inject the load_metadata_text function (called by init.lua)
---@param fn fun(searchable: SearchableObject): string?
function M.set_load_metadata_text_fn(fn)
  load_metadata_text_fn = fn
end

-- ============================================================================
-- Pattern Matching
-- ============================================================================

---Check if text matches pattern
---@param text string Text to search in
---@param pattern string Search pattern
---@param regex table? Compiled regex
---@param pattern_lower string? Pre-computed lowercase pattern (for case-insensitive searches)
---@return boolean matched
---@return string? matched_text
local function text_matches_pattern(text, pattern, regex, pattern_lower)
  local ui_state = State.get_ui_state()

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
        if Helpers.is_whole_word_match(search_in, match_start, match_end) then
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

-- Maximum positions per field (performance limit)
local MAX_POSITIONS_PER_FIELD = 100

---Find ALL match positions in text (main thread version)
---@param text string Text to search in
---@param pattern string Search pattern
---@param regex table? Compiled regex
---@param pattern_lower string? Pre-computed lowercase pattern
---@return MatchPosition[] positions Array of {start, end_, text}
local function find_all_positions(text, pattern, regex, pattern_lower)
  local ui_state = State.get_ui_state()

  if not text or text == "" or not pattern or pattern == "" then
    return {}
  end

  local positions = {}
  local search_in = text
  local search_for = pattern

  if not ui_state.case_sensitive then
    search_in = text:lower()
    search_for = pattern_lower or pattern:lower()
  end

  if ui_state.use_regex and regex then
    -- Use vim.regex for regex mode
    local pos = 0
    while pos < #search_in and #positions < MAX_POSITIONS_PER_FIELD do
      local match_start = regex:match_str(search_in:sub(pos + 1))
      if not match_start then break end

      -- match_start is 0-indexed offset from pos+1, convert to 1-indexed
      local abs_start = pos + match_start + 1
      local abs_end = abs_start + #pattern - 1  -- Approximate for regex

      -- For regex, try to find actual match end
      local _, actual_end = search_in:find(search_for, abs_start)
      if actual_end then
        abs_end = actual_end
      end

      -- Check whole word if needed
      local is_valid = not ui_state.whole_word or Helpers.is_whole_word_match(search_in, abs_start, abs_end)

      if is_valid then
        table.insert(positions, {
          start = abs_start,
          end_ = abs_end,
          text = text:sub(abs_start, abs_end),
        })
      end

      pos = abs_start  -- Move past this match
    end
  else
    -- Plain text mode
    local pos = 1
    while pos <= #search_in and #positions < MAX_POSITIONS_PER_FIELD do
      local match_start, match_end = search_in:find(search_for, pos, true)
      if not match_start then break end

      -- Check whole word if needed
      local is_valid = not ui_state.whole_word or Helpers.is_whole_word_match(search_in, match_start, match_end)

      if is_valid then
        table.insert(positions, {
          start = match_start,
          end_ = match_end,
          text = text:sub(match_start, match_end),
        })
      end

      pos = match_start + 1  -- Move past this match
    end
  end

  return positions
end

-- ============================================================================
-- Async Search Entry Point
-- ============================================================================

---Apply search filter asynchronously
---Uses OS threading when available for non-blocking execution,
---falls back to chunked processing when threading unavailable
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
function M.apply_search_async(pattern, callback)
  -- Invalidate visible count cache since loaded_objects may have changed
  Render.invalidate_visible_count_cache()

  -- Try threaded search first (always preferred for non-blocking UI)
  if Thread.is_available() then
    local started = M._apply_search_threaded(pattern, callback)
    if started then
      return  -- Threaded search running
    end
    -- Thread failed to start, fall through to chunked processing
  end

  -- Fallback to chunked processing
  M._apply_search_chunked(pattern, callback)
end

-- ============================================================================
-- Chunked Search (Fallback)
-- ============================================================================

---Apply search using chunked processing with vim.schedule() yields
---This is the fallback when threading is unavailable or fails
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
function M._apply_search_chunked(pattern, callback)
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  -- Cancel any in-progress search
  local search_cancel_token = State.get_search_cancel_token()
  if search_cancel_token then
    search_cancel_token:cancel("New search started")
  end

  -- Create new cancellation token
  search_cancel_token = Cancellation.create_token()
  State.set_search_cancel_token(search_cancel_token)
  local cancel_token = search_cancel_token

  local max_results = 500

  -- Pre-count objects that will be searched (after system/type filtering)
  local total_objects = 0
  for _, obj in ipairs(ui_state.loaded_objects) do
    if ui_state.show_system or not Helpers.is_system_object(obj) then
      if Helpers.should_show_object_type(obj) then
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
      if ui_state.show_system or not Helpers.is_system_object(obj) then
        -- Filter by object type
        if Helpers.should_show_object_type(obj) then
          table.insert(ui_state.filtered_results, {
            searchable = obj,
            match_type = "none",
            match_details = {},
            display_name = Helpers.build_display_name(obj),
            sort_priority = 0,
          })
          count = count + 1
        end
      end
    end
    State.set_search_cancel_token(nil)
    State.set_search_in_progress(false)
    State.set_search_progress(0)
    State.stop_search_spinner()
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
  State.set_search_in_progress(true)
  State.set_search_progress(0)
  State.set_search_total_objects(total_objects)
  State.set_search_start_time(vim.uv.hrtime())

  -- For small datasets, skip spinner (completes too fast to be useful)
  local use_progressive_display = total_objects >= State.SEARCH_CHUNK_SIZE
  if use_progressive_display then
    State.start_search_spinner()
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
  local chunk_size = State.SEARCH_CHUNK_SIZE

  ---Process one chunk of objects
  local function process_chunk()
    -- Check cancellation
    if cancel_token.is_cancelled then
      State.set_search_in_progress(false)
      State.set_search_progress(0)
      State.stop_search_spinner()
      return
    end

    -- Process this chunk
    local end_idx = math.min(idx + chunk_size - 1, total_objects)

    -- Update progress
    State.set_search_progress(math.floor((end_idx / total_objects) * 100))

    for i = idx, end_idx do
      if #filtered >= max_results then break end

      local searchable = ui_state.loaded_objects[i]

      -- Filter system objects unless show_system is enabled
      if not ui_state.show_system and Helpers.is_system_object(searchable) then
        goto continue_chunk
      end

      -- Filter by object type
      if not Helpers.should_show_object_type(searchable) then
        goto continue_chunk
      end

      local match_details = {}
      local matched_name = false
      local matched_def = false
      local matched_meta = false

      -- Search in name - find ALL positions
      if ui_state.search_names then
        local positions = find_all_positions(searchable.name, pattern, regex, pattern_lower)
        if #positions > 0 then
          matched_name = true
          table.insert(match_details, {
            field = "name",
            matched_text = positions[1].text,
            positions = positions,
          })
        end
      end

      -- Search in definition (lazy load) - find ALL positions
      if ui_state.search_definitions and not matched_name then
        local definition = load_definition_fn and load_definition_fn(searchable) or searchable.definition
        if definition then
          local positions = find_all_positions(definition, pattern, regex, pattern_lower)
          if #positions > 0 then
            matched_def = true
            table.insert(match_details, {
              field = "definition",
              matched_text = positions[1].text,
              positions = positions,
            })
          end
        end
      end

      -- Search in metadata (lazy load) - find ALL positions
      if ui_state.search_metadata and not matched_name and not matched_def then
        local metadata = load_metadata_text_fn and load_metadata_text_fn(searchable) or searchable.metadata_text
        if metadata then
          local positions = find_all_positions(metadata, pattern, regex, pattern_lower)
          if #positions > 0 then
            matched_meta = true
            table.insert(match_details, {
              field = "metadata",
              matched_text = positions[1].text,
              positions = positions,
            })
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
          display_name = Helpers.build_display_name(searchable),
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
      State.refresh_panels()

      -- Schedule next chunk (only for large datasets)
      vim.schedule(process_chunk)
    else
      -- Done processing - finalize
      if cancel_token.is_cancelled then
        State.set_search_in_progress(false)
        State.set_search_progress(0)
        State.stop_search_spinner()
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
      State.set_search_in_progress(false)
      State.set_search_progress(100)
      State.set_search_cancel_token(nil)
      State.stop_search_spinner()

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

-- ============================================================================
-- Search Control
-- ============================================================================

---Cancel any in-progress async search (chunked or threaded)
function M.cancel_search()
  -- Cancel chunked search token
  local search_cancel_token = State.get_search_cancel_token()
  if search_cancel_token then
    search_cancel_token:cancel("Search cancelled")
    State.set_search_cancel_token(nil)
  end
  -- Cancel threaded search
  local search_thread_task_id = State.get_search_thread_task_id()
  if search_thread_task_id then
    Thread.cancel(search_thread_task_id, "Search cancelled")
    State.set_search_thread_task_id(nil)
  end
  State.set_search_in_progress(false)
  State.set_search_progress(0)
  State.stop_search_spinner()
end

---Check if an async search is in progress
---@return boolean
function M.is_search_in_progress()
  return State.get_search_in_progress()
end

-- ============================================================================
-- Threaded Search
-- ============================================================================

---Apply search filter using OS thread for non-blocking execution
---@param pattern string Search pattern
---@param callback fun()? Optional callback when search completes
---@return boolean started Whether threaded search was started
function M._apply_search_threaded(pattern, callback)
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  -- Cancel any existing thread
  local search_thread_task_id = State.get_search_thread_task_id()
  if search_thread_task_id then
    Thread.cancel(search_thread_task_id, "New search started")
    State.set_search_thread_task_id(nil)
  end

  local total_objects = #ui_state.loaded_objects
  local max_results = 500

  -- Handle empty pattern case: show all objects (no pattern matching needed)
  if not pattern or pattern == "" then
    ui_state.filtered_results = {}
    local count = 0
    for _, obj in ipairs(ui_state.loaded_objects) do
      if count >= max_results then break end
      if ui_state.show_system or not Helpers.is_system_object(obj) then
        if Helpers.should_show_object_type(obj) then
          table.insert(ui_state.filtered_results, {
            searchable = obj,
            match_type = "none",
            match_details = {},
            display_name = Helpers.build_display_name(obj),
            sort_priority = 0,
          })
          count = count + 1
        end
      end
    end
    State.set_search_in_progress(false)
    State.set_search_progress(0)
    State.stop_search_spinner()
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
  State.refresh_panels()

  -- Prepare serializable objects for thread
  -- Extract only the data needed for searching (no class instances)
  -- Note: Metadata/definitions are preloaded asynchronously before search is enabled,
  -- so definition_loaded and metadata_loaded should be true for all objects
  local serializable_objects = {}
  for i, obj in ipairs(ui_state.loaded_objects) do
    -- Pre-filter system objects and object types to reduce thread work
    if ui_state.show_system or not Helpers.is_system_object(obj) then
      if Helpers.should_show_object_type(obj) then
        table.insert(serializable_objects, {
          idx = i,
          name = obj.name,
          schema_name = obj.schema_name,
          database_name = obj.database_name,
          server_name = obj.server_name,
          object_type = obj.object_type,
          display_name = Helpers.build_display_name(obj),
          unique_id = obj.unique_id,
          -- Include preloaded data (loaded asynchronously before search was enabled)
          definition = ui_state.search_definitions and obj.definition or nil,
          metadata_text = ui_state.search_metadata and obj.metadata_text or nil,
        })
      end
    end
  end

  -- Initialize search progress tracking
  State.set_search_in_progress(true)
  State.set_search_progress(0)
  State.set_search_total_objects(#serializable_objects)
  State.set_search_start_time(vim.uv.hrtime())
  State.start_search_spinner()

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
            -- Build match_details with positions from worker
            local match_details = {}
            if item.match_positions then
              if item.match_positions.name and #item.match_positions.name > 0 then
                table.insert(match_details, {
                  field = "name",
                  matched_text = item.match_positions.name[1].text,
                  positions = item.match_positions.name,
                })
              end
              if item.match_positions.definition and #item.match_positions.definition > 0 then
                table.insert(match_details, {
                  field = "definition",
                  matched_text = item.match_positions.definition[1].text,
                  positions = item.match_positions.definition,
                })
              end
              if item.match_positions.metadata and #item.match_positions.metadata > 0 then
                table.insert(match_details, {
                  field = "metadata",
                  matched_text = item.match_positions.metadata[1].text,
                  positions = item.match_positions.metadata,
                })
              end
            end
            -- Fallback if no positions (backward compatibility)
            if #match_details == 0 then
              match_details = {{ field = item.match_type or "name", matched_text = item.matched_text or "" }}
            end

            table.insert(accumulated_results, {
              searchable = original_obj,
              match_type = item.match_type or "name",
              match_details = match_details,
              display_name = item.display_name or Helpers.build_display_name(original_obj),
              sort_priority = item.match_type == "name" and 1 or (item.match_type == "definition" and 2 or 3),
            })
          end
        end
      end

      -- Update UI with intermediate results
      ui_state.filtered_results = accumulated_results
      if batch.progress then
        State.set_search_progress(batch.progress)
      end
      State.refresh_panels()
    end,
    on_progress = function(pct, message)
      State.set_search_progress(pct)
      -- Spinner handles re-rendering
    end,
    on_complete = function(result, error_msg)
      State.set_search_thread_task_id(nil)

      if error_msg then
        -- Error occurred - fall back to non-threaded search
        vim.notify(
          string.format("[SSNS] Search thread error, falling back: %s", tostring(error_msg)),
          vim.log.levels.DEBUG
        )
        State.set_search_in_progress(false)
        State.set_search_progress(0)
        State.stop_search_spinner()
        -- Fall back to chunked (non-threaded) search
        M._apply_search_chunked(pattern, callback)
        return
      end

      if result and result.cancelled then
        -- Cancelled - don't update results
        State.set_search_in_progress(false)
        State.set_search_progress(0)
        State.stop_search_spinner()
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
      State.set_search_in_progress(false)
      State.set_search_progress(100)
      State.stop_search_spinner()

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
    State.set_search_in_progress(false)
    State.set_search_progress(0)
    State.stop_search_spinner()
    return false
  end

  State.set_search_thread_task_id(task_id)
  return true
end

return M
