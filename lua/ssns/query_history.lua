---@class QueryHistoryEntry
---A single query execution entry
---@field id number Unique entry ID within buffer
---@field query string Full SQL query text
---@field timestamp string ISO 8601 timestamp (YYYY-MM-DD HH:MM:SS)
---@field execution_time_ms number Query execution time in milliseconds
---@field status "success"|"error" Execution status
---@field source "executed"|"auto_save" Entry source (default: "executed")
---@field row_count number? Number of rows returned (success only)
---@field error_message string? Error message (error only)
---@field error_line number? Error line number (error only)

---@class QueryBufferHistory
---History for a single query buffer/tab
---@field buffer_id string Unique buffer identifier (buffer number or file path)
---@field buffer_name string Display name for the buffer
---@field server_name string Database server name
---@field database string? Database name
---@field created_at string Timestamp when buffer history was created
---@field last_accessed string Timestamp of last query execution
---@field entries QueryHistoryEntry[] Query executions for this buffer (newest first)
---@field next_entry_id number Next entry ID to assign
---@field last_auto_save_content string? Last auto-saved content (for duplicate prevention)

---@class QueryHistoryConfig
---Configuration for query history
---@field enabled boolean Enable history tracking
---@field max_buffers number Maximum buffer histories to keep
---@field max_entries_per_buffer number Maximum entries per buffer
---@field auto_persist boolean Auto-save to file after changes
---@field persist_file string Path to history file
---@field exclude_patterns string[] Queries to exclude from history

---@class QueryHistory
---Query execution history manager (RedGate-style nested per buffer)
local QueryHistory = {}

---@type table<string, QueryBufferHistory> Buffer ID -> Buffer history
QueryHistory.buffers = {}

---@type string[] List of buffer IDs in LRU order (most recent first)
QueryHistory.buffer_lru = {}

---@type number Maximum buffer histories to keep
QueryHistory.max_buffers = 100

---@type number Maximum entries per buffer
QueryHistory.max_entries_per_buffer = 100

---@type boolean Auto-persist to file
QueryHistory.auto_persist = true

---@type string History file path
QueryHistory.persist_file = vim.fn.stdpath('data') .. '/ssns/query_history.json'

---@type string[] Exclude patterns
QueryHistory.exclude_patterns = {}

---Initialize query history (load from file if exists)
---@return boolean success
function QueryHistory.init()
  -- Create data directory if needed
  local data_dir = vim.fn.stdpath('data') .. '/ssns'
  vim.fn.mkdir(data_dir, 'p')

  -- Load from file if auto_persist enabled
  if QueryHistory.auto_persist then
    QueryHistory.load_from_file()
  end

  return true
end

---Generate a unique buffer ID
---@param bufnr number Buffer number
---@param buffer_name string? Optional buffer name/path
---@return string buffer_id
local function generate_buffer_id(bufnr, buffer_name)
  -- Use buffer name if provided, otherwise use buffer number
  if buffer_name and buffer_name ~= "" then
    return buffer_name
  else
    return string.format("buffer_%d", bufnr)
  end
end

---Update LRU list when buffer is accessed
---@param buffer_id string
local function update_lru(buffer_id)
  -- Remove from current position
  for i, id in ipairs(QueryHistory.buffer_lru) do
    if id == buffer_id then
      table.remove(QueryHistory.buffer_lru, i)
      break
    end
  end

  -- Insert at front (most recently used)
  table.insert(QueryHistory.buffer_lru, 1, buffer_id)

  -- Trim LRU list if exceeds max
  while #QueryHistory.buffer_lru > QueryHistory.max_buffers do
    local lru_id = table.remove(QueryHistory.buffer_lru)
    QueryHistory.buffers[lru_id] = nil
  end
end

---Get or create buffer history
---@param bufnr number Buffer number
---@param buffer_name string? Buffer name/path
---@param server_name string Server name
---@param database string? Database name
---@return QueryBufferHistory
local function get_or_create_buffer_history(bufnr, buffer_name, server_name, database)
  local buffer_id = generate_buffer_id(bufnr, buffer_name)

  -- Create new buffer history if doesn't exist
  if not QueryHistory.buffers[buffer_id] then
    QueryHistory.buffers[buffer_id] = {
      buffer_id = buffer_id,
      buffer_name = buffer_name or string.format("Buffer %d", bufnr),
      server_name = server_name,
      database = database,
      created_at = os.date("%Y-%m-%d %H:%M:%S"),
      last_accessed = os.date("%Y-%m-%d %H:%M:%S"),
      entries = {},
      next_entry_id = 1,
    }
  else
    -- Update last accessed time
    QueryHistory.buffers[buffer_id].last_accessed = os.date("%Y-%m-%d %H:%M:%S")
  end

  -- Update LRU
  update_lru(buffer_id)

  return QueryHistory.buffers[buffer_id]
end

---Check if query matches exclude patterns
---@param query string
---@return boolean
local function is_excluded(query)
  local normalized = query:gsub("%s+", " "):lower():gsub("^%s+", ""):gsub("%s+$", "")

  for _, pattern in ipairs(QueryHistory.exclude_patterns) do
    local pattern_normalized = pattern:lower():gsub("%s+", " ")
    if normalized:find(pattern_normalized, 1, true) then
      return true
    end
  end

  return false
end

---Add query execution to buffer history
---@param bufnr number Buffer number
---@param buffer_name string? Buffer name/path
---@param entry QueryHistoryEntry Entry to add (without ID)
---@return boolean success
function QueryHistory.add_entry(bufnr, buffer_name, entry)
  -- Skip if excluded
  if is_excluded(entry.query) then
    return false
  end

  -- Get or create buffer history
  local buffer_history = get_or_create_buffer_history(
    bufnr,
    buffer_name,
    entry.server_name,
    entry.database
  )

  -- Assign entry ID and default source
  entry.id = buffer_history.next_entry_id
  entry.source = entry.source or "executed"
  buffer_history.next_entry_id = buffer_history.next_entry_id + 1

  -- Insert at front (newest first)
  table.insert(buffer_history.entries, 1, entry)

  -- Trim if exceeds max entries per buffer
  while #buffer_history.entries > QueryHistory.max_entries_per_buffer do
    table.remove(buffer_history.entries)
  end

  -- Auto-save if enabled
  if QueryHistory.auto_persist then
    QueryHistory.save_to_file()
  end

  return true
end

---@type number Maximum auto-save entries per buffer
QueryHistory.max_auto_saves_per_buffer = 50

---Add auto-save entry to buffer history
---Skips if content is identical to last auto-save
---@param bufnr number Buffer number
---@param buffer_name string? Buffer name/path
---@param content string Buffer content to save
---@param server_name string Server name
---@param database string? Database name
---@return boolean success
function QueryHistory.add_auto_save_entry(bufnr, buffer_name, content, server_name, database)
  -- Skip empty content
  if not content or content:match("^%s*$") then
    return false
  end

  -- Get or create buffer history
  local buffer_history = get_or_create_buffer_history(
    bufnr,
    buffer_name,
    server_name,
    database
  )

  -- Skip if content is identical to last auto-save
  if buffer_history.last_auto_save_content == content then
    return false
  end

  -- Create auto-save entry
  local entry = {
    id = buffer_history.next_entry_id,
    query = content,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    execution_time_ms = 0,
    status = "success",  -- Auto-saves are neutral, use success for display
    source = "auto_save",
  }
  buffer_history.next_entry_id = buffer_history.next_entry_id + 1

  -- Update last auto-save content
  buffer_history.last_auto_save_content = content

  -- Insert at front (newest first)
  table.insert(buffer_history.entries, 1, entry)

  -- Count and trim auto-save entries if exceeds max
  local auto_save_count = 0
  for i = #buffer_history.entries, 1, -1 do
    local e = buffer_history.entries[i]
    if e.source == "auto_save" then
      auto_save_count = auto_save_count + 1
      if auto_save_count > QueryHistory.max_auto_saves_per_buffer then
        table.remove(buffer_history.entries, i)
      end
    end
  end

  -- Also trim total entries if exceeds max
  while #buffer_history.entries > QueryHistory.max_entries_per_buffer do
    table.remove(buffer_history.entries)
  end

  -- Auto-save to file if enabled
  if QueryHistory.auto_persist then
    QueryHistory.save_to_file()
  end

  return true
end

---Get buffer history by buffer ID or number
---@param bufnr_or_id number|string Buffer number or buffer ID
---@param buffer_name string? Buffer name for ID generation
---@return QueryBufferHistory?
function QueryHistory.get_buffer_history(bufnr_or_id, buffer_name)
  local buffer_id

  if type(bufnr_or_id) == "number" then
    buffer_id = generate_buffer_id(bufnr_or_id, buffer_name)
  else
    buffer_id = bufnr_or_id
  end

  return QueryHistory.buffers[buffer_id]
end

---Get all buffer histories sorted by last accessed (most recent first)
---@return QueryBufferHistory[]
function QueryHistory.get_all_buffer_histories()
  local histories = {}

  for _, buffer_id in ipairs(QueryHistory.buffer_lru) do
    local history = QueryHistory.buffers[buffer_id]
    if history then
      table.insert(histories, history)
    end
  end

  return histories
end

---Clear history for a specific buffer
---@param bufnr_or_id number|string Buffer number or buffer ID
---@param buffer_name string? Buffer name for ID generation
---@return boolean success
function QueryHistory.clear_buffer_history(bufnr_or_id, buffer_name)
  local buffer_id

  if type(bufnr_or_id) == "number" then
    buffer_id = generate_buffer_id(bufnr_or_id, buffer_name)
  else
    buffer_id = bufnr_or_id
  end

  if not QueryHistory.buffers[buffer_id] then
    vim.notify("No history for this buffer", vim.log.levels.WARN)
    return false
  end

  QueryHistory.buffers[buffer_id] = nil

  -- Remove from LRU
  for i, id in ipairs(QueryHistory.buffer_lru) do
    if id == buffer_id then
      table.remove(QueryHistory.buffer_lru, i)
      break
    end
  end

  if QueryHistory.auto_persist then
    QueryHistory.save_to_file()
  end

  vim.notify("Buffer history cleared", vim.log.levels.INFO)
  return true
end

---Clear all history
---@return boolean success
function QueryHistory.clear_all()
  local buffer_count = #QueryHistory.buffer_lru
  local entry_count = 0

  for _, buffer_history in pairs(QueryHistory.buffers) do
    entry_count = entry_count + #buffer_history.entries
  end

  if buffer_count == 0 then
    vim.notify("Query history is already empty", vim.log.levels.WARN)
    return false
  end

  QueryHistory.buffers = {}
  QueryHistory.buffer_lru = {}

  if QueryHistory.auto_persist then
    QueryHistory.save_to_file()
  end

  vim.notify(
    string.format("Cleared %d buffers with %d total entries", buffer_count, entry_count),
    vim.log.levels.INFO
  )
  return true
end

---Save history to file
---@return boolean success
function QueryHistory.save_to_file()
  local data = {
    version = 1,
    saved_at = os.date("%Y-%m-%d %H:%M:%S"),
    buffers = QueryHistory.buffers,
    buffer_lru = QueryHistory.buffer_lru,
  }

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    vim.notify("Failed to encode query history: " .. tostring(json), vim.log.levels.ERROR)
    return false
  end

  local f = io.open(QueryHistory.persist_file, 'w')
  if not f then
    vim.notify("Failed to open history file for writing: " .. QueryHistory.persist_file, vim.log.levels.ERROR)
    return false
  end

  f:write(json)
  f:close()

  return true
end

---Load history from file
---@return boolean success
function QueryHistory.load_from_file()
  local f = io.open(QueryHistory.persist_file, 'r')
  if not f then
    -- File doesn't exist yet, not an error
    return true
  end

  local content = f:read('*a')
  f:close()

  if not content or content == "" then
    return true
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify("Failed to parse query history file", vim.log.levels.WARN)
    return false
  end

  QueryHistory.buffers = data.buffers or {}
  QueryHistory.buffer_lru = data.buffer_lru or {}

  return true
end

---Export history to file
---@param filepath string Output file path
---@param format "json"|"txt"|"sql" Export format
---@return boolean success
function QueryHistory.export(filepath, format)
  format = format or "json"

  if format == "json" then
    -- Copy current history file
    local data = {
      version = 1,
      exported_at = os.date("%Y-%m-%d %H:%M:%S"),
      buffers = QueryHistory.buffers,
      buffer_lru = QueryHistory.buffer_lru,
    }

    local json = vim.fn.json_encode(data)
    local f = io.open(filepath, 'w')
    if not f then
      vim.notify("Failed to open export file: " .. filepath, vim.log.levels.ERROR)
      return false
    end

    f:write(json)
    f:close()
    return true

  elseif format == "txt" then
    -- Export as readable text
    local lines = {}
    table.insert(lines, "SSNS Query History Export")
    table.insert(lines, "Exported: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, string.rep("=", 80))
    table.insert(lines, "")

    for _, buffer_id in ipairs(QueryHistory.buffer_lru) do
      local buffer_history = QueryHistory.buffers[buffer_id]
      if buffer_history then
        table.insert(lines, string.format("Buffer: %s", buffer_history.buffer_name))
        table.insert(lines, string.format("  Server: %s | Database: %s",
          buffer_history.server_name, buffer_history.database or "N/A"))
        table.insert(lines, string.format("  Created: %s | Last Accessed: %s",
          buffer_history.created_at, buffer_history.last_accessed))
        table.insert(lines, "")

        for i, entry in ipairs(buffer_history.entries) do
          table.insert(lines, string.format("  [%d] %s | %s | %dms",
            i, entry.timestamp, entry.status, entry.execution_time_ms or 0))
          table.insert(lines, "  " .. string.rep("-", 76))

          -- Add query lines with indentation
          for _, query_line in ipairs(vim.split(entry.query, "\n")) do
            table.insert(lines, "  " .. query_line)
          end

          if entry.status == "error" and entry.error_message then
            table.insert(lines, "  ERROR: " .. entry.error_message)
          end
          table.insert(lines, "")
        end

        table.insert(lines, string.rep("=", 80))
        table.insert(lines, "")
      end
    end

    local f = io.open(filepath, 'w')
    if not f then
      vim.notify("Failed to open export file: " .. filepath, vim.log.levels.ERROR)
      return false
    end

    f:write(table.concat(lines, "\n"))
    f:close()
    return true

  else
    vim.notify("Unsupported export format: " .. format, vim.log.levels.ERROR)
    return false
  end
end

---Get history statistics
---@return table stats
function QueryHistory.get_stats()
  local total_entries = 0
  local success_count = 0
  local error_count = 0

  for _, buffer_history in pairs(QueryHistory.buffers) do
    for _, entry in ipairs(buffer_history.entries) do
      total_entries = total_entries + 1
      if entry.status == "success" then
        success_count = success_count + 1
      else
        error_count = error_count + 1
      end
    end
  end

  return {
    total_buffers = #QueryHistory.buffer_lru,
    max_buffers = QueryHistory.max_buffers,
    total_entries = total_entries,
    max_entries_per_buffer = QueryHistory.max_entries_per_buffer,
    success_count = success_count,
    error_count = error_count,
    auto_persist = QueryHistory.auto_persist,
    persist_file = QueryHistory.persist_file,
  }
end

return QueryHistory
