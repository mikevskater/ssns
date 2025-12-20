-- Search Worker
-- Filters objects by pattern matching
-- Pure Lua only - NO vim.* APIs
--
-- Input: { objects, pattern, options }
-- Output: batches of matching objects with progress updates
--
-- Options:
--   case_sensitive: boolean - Match case exactly
--   use_regex: boolean - Use Lua pattern matching (not plain text)
--   whole_word: boolean - Match whole words only
--   search_names: boolean - Search in object names (default true)
--   search_definitions: boolean - Search in definitions
--   search_metadata: boolean - Search in metadata
--   batch_interval_ms: number - Time between batch sends in milliseconds (default 100)
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local objects = _INPUT.objects or {}
local pattern = _INPUT.pattern or ""
local options = _INPUT.options or {}
local batch_interval_ms = options.batch_interval_ms or 100
local case_sensitive = options.case_sensitive or false
local use_regex = options.use_regex or false
local whole_word = options.whole_word or false
local search_names = options.search_names ~= false  -- default true
local search_definitions = options.search_definitions or false
local search_metadata = options.search_metadata or false

-- Convert interval to seconds for os.clock()
local batch_interval_sec = batch_interval_ms / 1000

-- Prepare pattern for matching
local match_pattern = pattern
if not case_sensitive and pattern ~= "" then
  match_pattern = pattern:lower()
end

-- Escape pattern for plain text search (when not using regex)
local function escape_pattern(str)
  return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Check if text matches pattern
-- Returns: matched (boolean), matched_text (string or nil)
local function text_matches(text, pat)
  if not text or text == "" then
    return false, nil
  end

  local search_text = case_sensitive and text or text:lower()

  if use_regex then
    -- Use Lua pattern matching
    local match_start, match_end = search_text:find(pat)
    if match_start then
      if whole_word then
        -- Check word boundaries for regex match
        local before_ok = match_start == 1 or not search_text:sub(match_start - 1, match_start - 1):match("%w")
        local after_ok = match_end == #search_text or not search_text:sub(match_end + 1, match_end + 1):match("%w")
        if before_ok and after_ok then
          return true, text:sub(match_start, match_end)
        end
        -- Try to find a word-boundary match
        local pos = 1
        while pos <= #search_text do
          match_start, match_end = search_text:find(pat, pos)
          if not match_start then break end
          before_ok = match_start == 1 or not search_text:sub(match_start - 1, match_start - 1):match("%w")
          after_ok = match_end == #search_text or not search_text:sub(match_end + 1, match_end + 1):match("%w")
          if before_ok and after_ok then
            return true, text:sub(match_start, match_end)
          end
          pos = match_start + 1
        end
        return false, nil
      else
        return true, text:sub(match_start, match_end)
      end
    end
    return false, nil
  else
    -- Plain text search
    if whole_word then
      -- Use word boundary pattern for whole word matching
      local escaped = escape_pattern(pat)
      local word_pattern = "%f[%w]" .. escaped .. "%f[%W]"
      local match = search_text:match(word_pattern)
      if match then
        return true, match
      end
      return false, nil
    else
      -- Simple substring search (plain = true for literal match)
      local match_start = search_text:find(pat, 1, true)
      if match_start then
        return true, text:sub(match_start, match_start + #pat - 1)
      end
      return false, nil
    end
  end
end

-- Match function - returns (matched, match_type, matched_text)
local function matches(obj)
  if pattern == "" then
    return true, "all", nil
  end

  -- Check name match first (highest priority)
  if search_names then
    local name_matched, name_text = text_matches(obj.name, match_pattern)
    if name_matched then
      return true, "name", name_text
    end
    -- Also check display_name
    local display_matched, display_text = text_matches(obj.display_name, match_pattern)
    if display_matched then
      return true, "name", display_text
    end
  end

  -- Check definition match (medium priority)
  if search_definitions and obj.definition then
    local def_matched, def_text = text_matches(obj.definition, match_pattern)
    if def_matched then
      return true, "definition", def_text
    end
  end

  -- Check metadata match (lowest priority)
  if search_metadata and obj.metadata_text then
    local meta_matched, meta_text = text_matches(obj.metadata_text, match_pattern)
    if meta_matched then
      return true, "metadata", meta_text
    end
  end

  return false, nil, nil
end

-- Process objects with time-based batching
local batch = {}
local total = #objects
local last_progress = 0
local last_batch_time = os.clock()

for i, obj in ipairs(objects) do
  local matched, match_type, matched_text = matches(obj)

  if matched then
    table.insert(batch, {
      idx = obj.idx or i,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      match_type = match_type,
      matched_text = matched_text,
      display_name = obj.display_name,
      unique_id = obj.unique_id,
    })
  end

  -- Send batch when time interval has elapsed (and we have results)
  local current_time = os.clock()
  if #batch > 0 and (current_time - last_batch_time) >= batch_interval_sec then
    local progress = math.floor((i / total) * 100)
    send({
      type = "batch",
      items = batch,
      progress = progress,
    })
    batch = {}
    last_batch_time = current_time
  end

  -- Send progress updates every 10%
  local current_progress = math.floor((i / total) * 10) * 10
  if current_progress > last_progress then
    last_progress = current_progress
    send({
      type = "progress",
      pct = current_progress,
      message = string.format("Processing %d/%d objects...", i, total),
    })
  end
end

-- Send remaining batch
if #batch > 0 then
  send({
    type = "batch",
    items = batch,
    progress = 100,
  })
end

-- Send completion
send({
  type = "complete",
  result = { total_processed = total },
})
