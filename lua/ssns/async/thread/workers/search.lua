-- Search Worker
-- Filters objects by pattern matching
-- Pure Lua only - NO vim.* APIs
--
-- Input: { objects, pattern, options }
-- Output: batches of matching objects with progress updates

local async_handle, input_json = ...

-- Parse input
local input = json_decode(input_json)
if not input then
  async_handle:send(json_encode({ type = "error", error = "Failed to parse input" }))
  return
end

local objects = input.objects or {}
local pattern = input.pattern or ""
local options = input.options or {}
local batch_size = options.batch_size or 50
local case_sensitive = options.case_sensitive
local use_regex = options.use_regex
local whole_word = options.whole_word
local search_names = options.search_names ~= false  -- default true
local search_definitions = options.search_definitions
local search_metadata = options.search_metadata

-- Prepare pattern for matching
local match_pattern = pattern
if not case_sensitive then
  match_pattern = pattern:lower()
end

-- Build regex pattern if whole word matching
local function check_whole_word(text, pat)
  if not whole_word then
    return text:find(pat, 1, not use_regex) ~= nil
  end
  -- Whole word matching
  local pattern_escaped = pat:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  local word_pattern = "%f[%w]" .. pattern_escaped .. "%f[%W]"
  return text:match(word_pattern) ~= nil
end

-- Match function
local function matches(obj)
  if pattern == "" then
    return true, "all"
  end

  local text_to_search = ""

  -- Build searchable text
  if search_names then
    text_to_search = text_to_search .. " " .. (obj.name or "")
    text_to_search = text_to_search .. " " .. (obj.display_name or "")
    text_to_search = text_to_search .. " " .. (obj.full_name or "")
  end

  if search_definitions and obj.definition then
    text_to_search = text_to_search .. " " .. obj.definition
  end

  if search_metadata and obj.metadata_text then
    text_to_search = text_to_search .. " " .. obj.metadata_text
  end

  if not case_sensitive then
    text_to_search = text_to_search:lower()
  end

  if check_whole_word(text_to_search, match_pattern) then
    -- Determine match type
    if search_names and obj.name and check_whole_word(
      case_sensitive and obj.name or obj.name:lower(),
      match_pattern
    ) then
      return true, "name"
    elseif search_definitions and obj.definition then
      return true, "definition"
    elseif search_metadata and obj.metadata_text then
      return true, "metadata"
    end
    return true, "name"
  end

  return false, nil
end

-- Process objects
local batch = {}
local total = #objects
local last_progress = 0

for i, obj in ipairs(objects) do
  local matched, match_type = matches(obj)

  if matched then
    table.insert(batch, {
      idx = obj.idx or i,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      match_type = match_type,
      display_name = obj.display_name,
      unique_id = obj.unique_id,
    })
  end

  -- Send batch when full
  if #batch >= batch_size then
    local progress = math.floor((i / total) * 100)
    async_handle:send(json_encode({
      type = "batch",
      items = batch,
      progress = progress,
    }))
    batch = {}
  end

  -- Send progress updates every 10%
  local current_progress = math.floor((i / total) * 10) * 10
  if current_progress > last_progress then
    last_progress = current_progress
    async_handle:send(json_encode({
      type = "progress",
      pct = current_progress,
      message = string.format("Processing %d/%d objects...", i, total),
    }))
  end
end

-- Send remaining batch
if #batch > 0 then
  async_handle:send(json_encode({
    type = "batch",
    items = batch,
    progress = 100,
  }))
end

-- Send completion
async_handle:send(json_encode({
  type = "complete",
  result = { total_processed = total },
}))
