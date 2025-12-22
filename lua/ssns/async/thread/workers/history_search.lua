-- History Search Worker
-- Filters history entries by pattern matching
-- Pure Lua only - NO vim.* APIs
--
-- Input: { entries, pattern, options }
-- Output: batches of matching entries with match positions
--
-- entries format: { { buf_idx, entry_idx, query }, ... }
--
-- Options:
--   case_sensitive: boolean - Match case exactly
--   use_regex: boolean - Use Lua pattern matching (not plain text)
--   whole_word: boolean - Match whole words only
--   batch_interval_ms: number - Time between batch sends (default 100)
--
-- This code runs inside _WORKER_MAIN(send_message)
-- _INPUT is the decoded input table
-- send(msg) sends a message to the main thread

local entries = _INPUT.entries or {}
local pattern = _INPUT.pattern or ""
local options = _INPUT.options or {}
local batch_interval_ms = options.batch_interval_ms or 100
local case_sensitive = options.case_sensitive or false
local use_regex = options.use_regex or false
local whole_word = options.whole_word or false

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

-- Maximum positions per entry (performance limit)
local MAX_POSITIONS = 100

-- Check if match is at word boundaries
local function is_word_boundary_match(text, match_start, match_end)
  local before_ok = match_start == 1 or not text:sub(match_start - 1, match_start - 1):match("%w")
  local after_ok = match_end == #text or not text:sub(match_end + 1, match_end + 1):match("%w")
  return before_ok and after_ok
end

-- Find ALL match positions in text
-- Returns: MatchPosition[] Array of {start, end_, text}
local function find_all_matches(text, original_text, pat)
  if not text or text == "" or pat == "" then
    return {}
  end

  local positions = {}
  local pos = 1

  while pos <= #text and #positions < MAX_POSITIONS do
    local match_start, match_end

    if use_regex then
      match_start, match_end = text:find(pat, pos)
    else
      match_start, match_end = text:find(pat, pos, true)
      if match_start then
        match_end = match_start + #pat - 1
      end
    end

    if not match_start then break end

    -- Check whole word boundary if required
    local is_valid = not whole_word or is_word_boundary_match(text, match_start, match_end)

    if is_valid then
      table.insert(positions, {
        start = match_start,
        end_ = match_end,
        text = original_text:sub(match_start, match_end),
      })
    end

    pos = match_start + 1
  end

  return positions
end

-- Process entries with time-based batching
local batch = {}
local total = #entries
local last_progress = 0
local last_batch_time = os.clock()

for i, entry in ipairs(entries) do
  local query = entry.query or ""
  local search_text = case_sensitive and query or query:lower()
  local positions = find_all_matches(search_text, query, match_pattern)

  if #positions > 0 then
    table.insert(batch, {
      buf_idx = entry.buf_idx,
      entry_idx = entry.entry_idx,
      positions = positions,
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
      message = string.format("Searching %d/%d entries...", i, total),
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
