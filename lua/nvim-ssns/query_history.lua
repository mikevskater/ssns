---@class QuerySelectionRange
---Selection range within buffer (for partial executions)
---@field start_line number 1-based start line
---@field start_col number 1-based start column
---@field end_line number 1-based end line
---@field end_col number 1-based end column
---@field mode string Visual mode used: 'v' (char), 'V' (line), or '\x16' (block)

---@class QueryHistoryEntry
---A single query execution entry
---@field id number Unique entry ID within buffer
---@field query string SQL that was executed (may be selection or full buffer)
---@field buffer_content string? Full buffer content at execution time (for selection executions)
---@field selection QuerySelectionRange? Selection range if this was a partial execution
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
---@field buffers table<string, QueryBufferHistory> Buffer ID -> Buffer history
---@field buffer_lru string[] List of buffer IDs in LRU order (most recent first)
---@field max_buffers number Maximum buffer histories to keep (from config)
---@field max_entries_per_buffer number Maximum entries per buffer (from config)
---@field auto_persist boolean Auto-persist to file (from config)
---@field persist_file string History file path (from config)
---@field exclude_patterns string[] Exclude patterns (from config)
---@field max_auto_saves_per_buffer number Maximum auto-save entries per buffer (from config)
local QueryHistory = {
  buffers = {},
  buffer_lru = {},
  _configured = false,
}

---Load configuration from config.lua
---Called automatically by init() but can be called manually to reload config
function QueryHistory.configure()
  local Config = require('nvim-ssns.config')
  local cfg = Config.get().query_history or {}

  QueryHistory.max_buffers = cfg.max_buffers or 100
  QueryHistory.max_entries_per_buffer = cfg.max_entries_per_buffer or 100
  QueryHistory.auto_persist = cfg.auto_persist ~= false  -- Default true
  QueryHistory.persist_file = cfg.persist_file or (vim.fn.stdpath('data') .. '/ssns/query_history.json')
  QueryHistory.exclude_patterns = cfg.exclude_patterns or {}
  QueryHistory.max_auto_saves_per_buffer = cfg.max_auto_saves_per_buffer or 100

  QueryHistory._configured = true
end

---Initialize query history (load from file if exists)
---@return boolean success
function QueryHistory.init()
  -- Load configuration from config.lua
  if not QueryHistory._configured then
    QueryHistory.configure()
  end

  -- Create data directory if needed
  local data_dir = vim.fn.fnamemodify(QueryHistory.persist_file, ":h")
  vim.fn.mkdir(data_dir, 'p')

  -- Load from file if auto_persist enabled
  if QueryHistory.auto_persist then
    QueryHistory.load_from_file()
  end

  return true
end

---@type number Counter for generating unique buffer IDs within same millisecond
local buffer_id_counter = 0

---Generate a unique buffer ID (timestamp + counter based)
---This ensures uniqueness across sessions and prevents collisions
---@return string buffer_id Unique ID like "hist_1702500000000_1"
local function generate_unique_buffer_id()
  local timestamp = vim.loop.hrtime() / 1000000  -- Milliseconds
  buffer_id_counter = buffer_id_counter + 1
  return string.format("hist_%d_%d", timestamp, buffer_id_counter)
end

---Get buffer ID for a buffer, checking metadata first
---If buffer has stored history_buffer_id, use that; otherwise generate new one
---@param bufnr number Buffer number
---@return string buffer_id
local function get_buffer_id(bufnr)
  -- Check for stored buffer_id in buffer metadata
  local ok, stored_id = pcall(vim.api.nvim_buf_get_var, bufnr, 'ssns_history_buffer_id')
  if ok and stored_id and stored_id ~= "" then
    return stored_id
  end

  -- Generate new unique ID
  local new_id = generate_unique_buffer_id()

  -- Store in buffer metadata for future use
  pcall(vim.api.nvim_buf_set_var, bufnr, 'ssns_history_buffer_id', new_id)

  return new_id
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
---@param buffer_name string? Buffer display name (for UI)
---@param server_name string Server name
---@param database string? Database name
---@return QueryBufferHistory
local function get_or_create_buffer_history(bufnr, buffer_name, server_name, database)
  -- Get unique buffer_id (from metadata or generate new)
  local buffer_id = get_buffer_id(bufnr)

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
    -- Update last accessed time and buffer_name (in case it changed)
    QueryHistory.buffers[buffer_id].last_accessed = os.date("%Y-%m-%d %H:%M:%S")
    if buffer_name then
      QueryHistory.buffers[buffer_id].buffer_name = buffer_name
    end
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

  -- Trim if exceeds max entries per buffer (-1 = unlimited)
  if QueryHistory.max_entries_per_buffer >= 0 then
    while #buffer_history.entries > QueryHistory.max_entries_per_buffer do
      table.remove(buffer_history.entries)
    end
  end

  -- Auto-save if enabled (async to avoid blocking)
  if QueryHistory.auto_persist then
    QueryHistory.save_to_file_async()
  end

  return true
end

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

  -- Count and trim auto-save entries if exceeds max (-1 = unlimited)
  if QueryHistory.max_auto_saves_per_buffer >= 0 then
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
  end

  -- Also trim total entries if exceeds max (-1 = unlimited)
  if QueryHistory.max_entries_per_buffer >= 0 then
    while #buffer_history.entries > QueryHistory.max_entries_per_buffer do
      table.remove(buffer_history.entries)
    end
  end

  -- Auto-save to file if enabled (async to avoid blocking)
  if QueryHistory.auto_persist then
    QueryHistory.save_to_file_async()
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
    QueryHistory.save_to_file_async()
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
    QueryHistory.save_to_file_async()
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

-- ============================================================================
-- Async Methods
-- ============================================================================

---Save history to file asynchronously
---@param callback fun(success: boolean, error: string?)? Optional callback
function QueryHistory.save_to_file_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')

  local data = {
    version = 1,
    saved_at = os.date("%Y-%m-%d %H:%M:%S"),
    buffers = QueryHistory.buffers,
    buffer_lru = QueryHistory.buffer_lru,
  }

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    if callback then
      callback(false, "Failed to encode query history: " .. tostring(json))
    end
    return
  end

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(QueryHistory.persist_file, ":h")
  FileIO.mkdir_async(dir, function(mkdir_success, mkdir_err)
    if not mkdir_success then
      if callback then
        callback(false, "Failed to create directory: " .. (mkdir_err or "unknown error"))
      end
      return
    end

    FileIO.write_async(QueryHistory.persist_file, json, function(result)
      if callback then
        callback(result.success, result.error)
      end
    end)
  end)
end

---Load history from file asynchronously
---@param callback fun(success: boolean, error: string?)
function QueryHistory.load_from_file_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')

  -- Check if file exists
  FileIO.exists_async(QueryHistory.persist_file, function(exists, _)
    if not exists then
      -- File doesn't exist yet, not an error
      callback(true, nil)
      return
    end

    FileIO.read_async(QueryHistory.persist_file, function(result)
      if not result.success then
        callback(false, result.error)
        return
      end

      local content = result.data
      if not content or content == "" then
        callback(true, nil)
        return
      end

      local ok, data = pcall(vim.fn.json_decode, content)
      if not ok or not data then
        callback(false, "Failed to parse query history file")
        return
      end

      QueryHistory.buffers = data.buffers or {}
      QueryHistory.buffer_lru = data.buffer_lru or {}

      callback(true, nil)
    end)
  end)
end

---Initialize query history asynchronously
---@param callback fun(success: boolean, error: string?)
function QueryHistory.init_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')

  -- Load configuration from config.lua
  if not QueryHistory._configured then
    QueryHistory.configure()
  end

  -- Create data directory if needed (use directory from configured persist_file)
  local data_dir = vim.fn.fnamemodify(QueryHistory.persist_file, ":h")

  FileIO.mkdir_async(data_dir, function(mkdir_success, mkdir_err)
    if not mkdir_success then
      callback(false, "Failed to create data directory: " .. (mkdir_err or "unknown error"))
      return
    end

    -- Load from file if auto_persist enabled
    if QueryHistory.auto_persist then
      QueryHistory.load_from_file_async(callback)
    else
      callback(true, nil)
    end
  end)
end

---Export history to file asynchronously
---@param filepath string Output file path
---@param format "json"|"txt" Export format
---@param callback fun(success: boolean, error: string?)
function QueryHistory.export_async(filepath, format, callback)
  local FileIO = require('nvim-ssns.async.file_io')
  format = format or "json"

  local content

  if format == "json" then
    local data = {
      version = 1,
      exported_at = os.date("%Y-%m-%d %H:%M:%S"),
      buffers = QueryHistory.buffers,
      buffer_lru = QueryHistory.buffer_lru,
    }

    local ok, json = pcall(vim.fn.json_encode, data)
    if not ok then
      callback(false, "Failed to encode JSON: " .. tostring(json))
      return
    end
    content = json

  elseif format == "txt" then
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

    content = table.concat(lines, "\n")
  else
    callback(false, "Unsupported export format: " .. format)
    return
  end

  FileIO.write_async(filepath, content, function(result)
    callback(result.success, result.error)
  end)
end

return QueryHistory
