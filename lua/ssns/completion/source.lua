---SSNS blink.cmp completion source
---Provides SQL IntelliSense for tables, columns, procedures, and keywords
---@class SsnsCompletionSource
local Source = {}

---Performance statistics (only tracked when debug enabled)
---@class CompletionStats
local stats = {
  total_requests = 0,
  total_time_ms = 0,
  cache_hits = 0,
  cache_misses = 0,
  slow_requests = 0, -- > 100ms
  requests_by_type = {}, -- { TABLE = {count, total_ms, avg_ms}, ... }
  avg_time_ms = 0,
}

-- Debug logger for diagnostics
local Debug = require('ssns.debug')

---Constructor for the completion source
---@param opts table? User configuration options
---@return table source The source instance
function Source.new(opts)
  -- Validate options
  vim.validate({
    cache_ttl = { opts and opts.cache_ttl, 'number', true },
    max_items = { opts and opts.max_items, 'number', true },
    show_system_objects = { opts and opts.show_system_objects, 'boolean', true },
  })

  -- Create source instance
  local self = setmetatable({}, { __index = Source })

  -- Merge user options with defaults
  self.opts = vim.tbl_deep_extend('force', {
    cache_ttl = 30,              -- Cache completions for 30 seconds
    max_items = 100,             -- Limit completion items
    show_system_objects = false, -- Hide sys.* objects
    debug = false,               -- Enable debug logging
  }, opts or {})

  return self
end

---Check if source is enabled for current buffer
---@return boolean enabled True if source should be active
function Source:enabled()
  Debug.log("[COMPLETION] enabled() called")

  -- Only enable for SQL file types
  local ft = vim.bo.filetype
  if not (ft == 'sql' or ft == 'mysql' or ft == 'plsql' or ft == 'pgsql') then
    Debug.log(string.format("[COMPLETION] enabled() = false (filetype: %s)", ft))
    return false
  end

  -- Check if completion is enabled in config
  local config = require('ssns.config').get()
  if config.completion and config.completion.enabled == false then
    Debug.log("[COMPLETION] enabled() = false (disabled in config)")
    return false
  end

  Debug.log("[COMPLETION] enabled() = true")
  return true
end

---Get trigger characters for auto-completion
---@return string[] triggers Array of trigger characters
function Source:get_trigger_characters()
  Debug.log("[COMPLETION] get_trigger_characters() called")
  return { '.', '[', ' ' }
end

---Main completion method (async)
---@param ctx table blink.cmp context { line: string, cursor: {row, col}, bounds: {start_col, end_col}, filetype: string, bufnr: number }
---@param callback function Callback function(response: { items: table[], is_incomplete_backward?: boolean, is_incomplete_forward?: boolean })
---@return function? cancel Optional cancellation function
function Source:get_completions(ctx, callback)
  Debug.log(string.format("[COMPLETION] get_completions() called (filetype: %s, line: %s)",
    vim.bo.filetype, ctx.line or "nil"))

  -- Start performance timer
  local start_time = vim.loop.hrtime()

  -- Detect SQL context
  local context_result = self:detect_context(ctx)

  if not context_result then
    Debug.log("[COMPLETION] Context detection returned nil")
  else
    Debug.log(string.format("[COMPLETION] Context detected: type=%s, should_complete=%s",
      context_result.type or "nil",
      tostring(context_result.should_complete)))
  end

  -- If context detection failed or disabled, return empty
  if not context_result or not context_result.should_complete then
    Debug.log("[COMPLETION] Returning empty results (context check failed)")
    vim.schedule(function()
      callback({ items = {} })
    end)
    return
  end

  -- Get connection context for buffer
  local connection_ctx = self:get_connection(ctx.bufnr)

  if not connection_ctx then
    Debug.log(string.format("[COMPLETION] No connection for buffer %d", ctx.bufnr))
  else
    Debug.log(string.format("[COMPLETION] Connection: %s:%s",
      connection_ctx.server and connection_ctx.server.name or "nil",
      connection_ctx.database and connection_ctx.database.db_name or "nil"))
  end

  -- Prepare context for providers
  local provider_ctx = {
    bufnr = ctx.bufnr,
    connection = connection_ctx,
    sql_context = context_result,
  }

  -- Detect temp tables in buffer (lazy, on-demand)
  -- This runs once per buffer when completion is first triggered
  local Cache = require('ssns.cache')
  if not Cache.buffer_cache[ctx.bufnr] then
    -- Parse buffer for temp tables
    local success, _ = pcall(function()
      local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
      local query = table.concat(lines, '\n')

      local TempTableTracker = require('ssns.completion.metadata.temp_tables')
      local temp_tables = TempTableTracker.detect_temp_tables(query, ctx.bufnr)

      -- Add to buffer cache
      for _, temp_table in ipairs(temp_tables) do
        Cache.add_buffer_temp_table(ctx.bufnr, temp_table, 1) -- Chunk 1 by default
      end
    end)

    -- Silent failure - temp table detection is optional
    if not success then
      -- Initialize empty cache so we don't retry every time
      Cache.buffer_cache[ctx.bufnr] = {
        temp_tables = {},
        go_chunks = {},
        last_go_line = 0,
      }
    end
  end

  -- Create callback wrapper to apply limits and track performance
  local wrapped_callback = function(items)
    Debug.log(string.format("[COMPLETION] Provider returned %d items", items and #items or 0))

    -- Calculate elapsed time
    local end_time = vim.loop.hrtime()
    local elapsed_ms = (end_time - start_time) / 1e6 -- Convert nanoseconds to milliseconds

    -- Apply max_items limit
    if self.opts.max_items > 0 and #items > self.opts.max_items then
      items = vim.list_slice(items, 1, self.opts.max_items)
      Debug.log(string.format("[COMPLETION] Limited to %d items", #items))
    end

    -- Update performance stats if debug enabled
    if self.opts.debug then
      self:_update_stats(context_result.type, elapsed_ms, #items)
    end

    -- Return results via callback (async pattern)
    vim.schedule(function()
      Debug.log(string.format("[COMPLETION] Calling blink callback with %d items", #items))
      callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    end)
  end

  -- Route to appropriate provider based on context type
  local Context = require('ssns.completion.context')

  Debug.log(string.format("[COMPLETION] Routing to provider for context type: %s (mode: %s)",
    context_result.type,
    context_result.mode or "nil"))

  if context_result.type == Context.Type.TABLE then
    -- Check if this is a JOIN context (Phase 10.8)
    if context_result.mode == "join" or context_result.mode == "join_qualified" then
      Debug.log("[COMPLETION] Calling JoinsProvider")
      local JoinsProvider = require('ssns.completion.providers.joins')
      JoinsProvider.get_completions(provider_ctx, wrapped_callback)
      return
    end

    -- Table/view/synonym completion (Phase 10.2)
    Debug.log("[COMPLETION] Calling TablesProvider")
    local TablesProvider = require('ssns.completion.providers.tables')
    TablesProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.COLUMN then
    -- Column completion (Phase 10.3 Week 2)
    Debug.log("[COMPLETION] Calling ColumnsProvider")
    local ColumnsProvider = require('ssns.completion.providers.columns')
    ColumnsProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.PROCEDURE then
    -- Procedure/function completion (Phase 10.6)
    Debug.log("[COMPLETION] Calling ProceduresProvider")
    local ProceduresProvider = require('ssns.completion.providers.procedures')
    ProceduresProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.PARAMETER then
    -- Parameter completion (Phase 10.6)
    Debug.log("[COMPLETION] Calling ParametersProvider")
    local ParametersProvider = require('ssns.completion.providers.parameters')
    ParametersProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.DATABASE then
    -- Database completion
    Debug.log("[COMPLETION] Calling DatabasesProvider")
    local DatabasesProvider = require('ssns.completion.providers.databases')
    DatabasesProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.SCHEMA then
    -- Schema completion
    Debug.log("[COMPLETION] Calling SchemasProvider")
    local SchemasProvider = require('ssns.completion.providers.schemas')
    SchemasProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.KEYWORD then
    -- Keyword completion (Phase 10.7)
    Debug.log("[COMPLETION] Calling KeywordsProvider + SnippetsProvider")
    local KeywordsProvider = require('ssns.completion.providers.keywords')
    local SnippetsProvider = require('ssns.completion.providers.snippets')

    -- Get both keywords and snippets
    local items = {}

    -- Get keywords
    local keyword_success, keyword_items = pcall(KeywordsProvider._get_completions_impl, provider_ctx)
    if keyword_success and keyword_items then
      vim.list_extend(items, keyword_items)
    end

    -- Get snippets
    local snippet_success, snippet_items = pcall(SnippetsProvider._get_completions_impl, provider_ctx)
    if snippet_success and snippet_items then
      vim.list_extend(items, snippet_items)
    end

    wrapped_callback(items)
    return
  else
    -- Unknown context - no completions
    Debug.log(string.format("[COMPLETION] Unknown context type: %s, returning empty",
      tostring(context_result.type)))
    wrapped_callback({})
    return
  end
end

---Detect SQL context from cursor position
---@param ctx table blink.cmp context
---@return table? context SQL context or nil if disabled
function Source:detect_context(ctx)
  local Context = require('ssns.completion.context')

  -- Optional: Log tree-sitter availability in debug mode
  if self.opts.debug then
    local Treesitter = require('ssns.completion.metadata.treesitter')
    if not Treesitter.is_available() then
      self:log("Tree-sitter SQL parser not available, using regex fallback", vim.log.levels.DEBUG)
    end
  end

  -- Use full context detection with comment/string checks
  local success, context = pcall(function()
    return Context.detect_full(ctx.bufnr, ctx.cursor[1], ctx.cursor[2])
  end)

  if not success then
    if self.opts.debug then
      vim.notify(
        string.format("[SSNS Completion] Context detection error: %s", tostring(context)),
        vim.log.levels.WARN
      )
    end
    return nil
  end

  return context
end

---Lazy-load documentation for completion item (optional)
---@param item table LSP CompletionItem
---@param callback function Callback function(item: table)
function Source:resolve(item, callback)
  -- For now, just return the item as-is
  -- In later phases, we can lazy-load expensive documentation here
  -- Example: fetch column constraints, FK relationships, etc.

  vim.schedule(function()
    callback(item)
  end)
end

---Get active database connection for current buffer
---@param bufnr number Buffer number
---@return table? connection { server: ServerClass, database: DbClass, connection_string: string }
function Source:get_connection(bufnr)
  local Cache = require('ssns.cache')

  -- Try to get buffer-local database connection
  local db_key = vim.b[bufnr].ssns_db_key
  Debug.log(string.format("[CONNECTION] get_connection(%d): db_key = %s",
    bufnr, tostring(db_key)))

  if not db_key then
    -- No connection associated with buffer
    Debug.log(string.format("[CONNECTION] get_connection(%d): No db_key found", bufnr))
    return nil
  end

  -- Parse db_key format: "server_name:database_name"
  local server_name, db_name = db_key:match("^([^:]+):(.+)$")
  Debug.log(string.format("[CONNECTION] get_connection(%d): Parsed server=%s, db=%s",
    bufnr, tostring(server_name), tostring(db_name)))

  if not server_name or not db_name then
    Debug.log(string.format("[CONNECTION] get_connection(%d): Failed to parse db_key", bufnr))
    return nil
  end

  -- Find server and database in cache
  local server = Cache.find_server(server_name)
  if not server then
    Debug.log(string.format("[CONNECTION] get_connection(%d): Server '%s' not found in cache",
      bufnr, server_name))
    return nil
  end
  Debug.log(string.format("[CONNECTION] get_connection(%d): Found server '%s'",
    bufnr, server_name))

  local database = server:find_database(db_name)
  if not database then
    Debug.log(string.format("[CONNECTION] get_connection(%d): Database '%s' not found on server '%s'",
      bufnr, db_name, server_name))
    return nil
  end
  Debug.log(string.format("[CONNECTION] get_connection(%d): Found database '%s'",
    bufnr, db_name))

  Debug.log(string.format("[CONNECTION] get_connection(%d): SUCCESS - returning connection",
    bufnr))
  return {
    server = server,
    database = database,
    connection_string = server.connection_string,
  }
end

---Get active schema for current buffer/database
---@param bufnr number Buffer number
---@return string? schema_name Default schema name (e.g., "dbo" for SQL Server)
function Source:get_active_schema(bufnr)
  local conn = self:get_connection(bufnr)
  if not conn then
    return nil
  end

  -- Get database type to determine default schema
  local db_type = conn.server:get_db_type()

  -- Default schemas by database type
  local default_schemas = {
    sqlserver = "dbo",
    postgres = "public",
    mysql = nil, -- MySQL doesn't use schemas
    sqlite = nil, -- SQLite doesn't use schemas
  }

  return default_schemas[db_type]
end

---Debug helper: log message if debug enabled
---@param message string Message to log
---@param level number? Log level (default: INFO)
function Source:log(message, level)
  if self.opts.debug then
    level = level or vim.log.levels.INFO
    vim.notify(string.format("[SSNS Completion] %s", message), level)
  end
end

---Update performance statistics
---@param context_type string Context type (TABLE, COLUMN, etc.)
---@param elapsed_ms number Elapsed time in milliseconds
---@param item_count number Number of items returned
function Source:_update_stats(context_type, elapsed_ms, item_count)
  stats.total_requests = stats.total_requests + 1
  stats.total_time_ms = stats.total_time_ms + elapsed_ms
  stats.avg_time_ms = stats.total_time_ms / stats.total_requests

  -- Track by type
  if not stats.requests_by_type[context_type] then
    stats.requests_by_type[context_type] = { count = 0, total_ms = 0, avg_ms = 0 }
  end
  local type_stats = stats.requests_by_type[context_type]
  type_stats.count = type_stats.count + 1
  type_stats.total_ms = type_stats.total_ms + elapsed_ms
  type_stats.avg_ms = type_stats.total_ms / type_stats.count

  -- Track slow requests (>100ms)
  if elapsed_ms > 100 then
    stats.slow_requests = stats.slow_requests + 1
    vim.notify(
      string.format(
        "[SSNS Completion] Slow completion detected: %s (%.2fms, %d items)",
        context_type,
        elapsed_ms,
        item_count
      ),
      vim.log.levels.WARN
    )
  end

  -- Log every request if debug enabled
  vim.notify(
    string.format("[SSNS Completion] %s: %.2fms (%d items)", context_type, elapsed_ms, item_count),
    vim.log.levels.DEBUG
  )
end

---Track cache hit (called by providers)
function Source:track_cache_hit()
  if self.opts.debug then
    stats.cache_hits = stats.cache_hits + 1
  end
end

---Track cache miss (called by providers)
function Source:track_cache_miss()
  if self.opts.debug then
    stats.cache_misses = stats.cache_misses + 1
  end
end

---Get performance statistics (for debugging)
---@return table stats Performance statistics
function Source:get_stats()
  return vim.tbl_deep_extend('force', {}, stats) -- Return copy
end

---Reset performance statistics
function Source:reset_stats()
  stats.total_requests = 0
  stats.total_time_ms = 0
  stats.cache_hits = 0
  stats.cache_misses = 0
  stats.slow_requests = 0
  stats.requests_by_type = {}
  stats.avg_time_ms = 0
end

-- Create and return a singleton instance for blink.cmp
-- blink.cmp expects a source instance, not a class
local instance = nil

---Get or create the singleton source instance
---@return table source The source instance
local function get_instance()
  if not instance then
    Debug.log("[SOURCE] Creating completion source instance")

    -- Get config from SSNS
    local Config = require('ssns.config')
    local config = Config.get()

    -- Create instance with config options
    instance = Source.new({
      cache_ttl = config.completion and config.completion.cache_ttl or 300,
      max_items = config.completion and config.completion.max_items or 100,
      debug = config.completion and config.completion.debug or false,
    })

    Debug.log("[SOURCE] Source instance created successfully")
  end
  return instance
end

-- Return source instance for blink.cmp with error handling
local success, result = pcall(get_instance)
if not success then
  Debug.log("[SOURCE] ERROR creating source instance: " .. tostring(result))
  -- Return a dummy source that always returns empty
  return {
    enabled = function() return false end,
    get_completions = function(ctx, cb) cb({ items = {} }) end,
  }
end

Debug.log("[SOURCE] Source module loaded successfully")
return result
