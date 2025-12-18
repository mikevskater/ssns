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

-- Token context utilities for identifier extraction
local TokenContext = require('ssns.completion.token_context')

-- Usage tracker for recording completion selections
local UsageTracker = require('ssns.completion.usage_tracker')

-- ============================================================================
-- Helper Functions for Selection Tracking
-- ============================================================================

---Extract the last identifier from text (handles qualified names and brackets)
---Uses TokenContext helpers instead of regex patterns
---@param text string Text to extract identifier from
---@return string? identifier The extracted identifier or nil
local function extract_last_identifier(text)
  -- Pattern matches:
  -- - Simple: "Employees"
  -- - Qualified: "dbo.Employees" or "schema.table.column"
  -- - Bracketed: "[Employee Name]"
  -- - Mixed: "dbo.[Employee Name]"

  -- Try bracketed identifier first: [...]
  local bracketed = TokenContext.extract_trailing_bracketed(text)
  if bracketed then
    return bracketed
  end

  -- Try qualified path: word.word.word or word
  local qualified = TokenContext.extract_trailing_identifier(text)
  if qualified then
    -- Return just the last part after final dot
    return TokenContext.get_last_name_part(qualified)
  end

  return nil
end

---Check if inserted text matches a completion item
---@param inserted_text string Text that was inserted
---@param item table Completion item
---@return boolean matches True if it matches
local function matches_completion_item(inserted_text, item)
  -- Normalize for comparison (case-insensitive, trim whitespace)
  local normalized_text = inserted_text:lower():gsub("^%s+", ""):gsub("%s+$", "")

  -- Check against label (e.g., "Employees")
  if item.label and item.label:lower() == normalized_text then
    return true
  end

  -- Check against insertText (e.g., "dbo.Employees")
  if item.insertText then
    local insert_normalized = item.insertText:lower()

    -- Match if inserted text equals insertText
    if insert_normalized == normalized_text then
      return true
    end

    -- Match if inserted text is the last part of insertText
    -- e.g., insertText="dbo.Employees", inserted="Employees"
    local insert_parts = vim.split(insert_normalized, "%.", { plain = true })
    if insert_parts[#insert_parts] == normalized_text then
      return true
    end
  end

  -- Check against filterText
  if item.filterText and item.filterText:lower() == normalized_text then
    return true
  end

  return false
end

---Build full path for an item based on its data
---@param item_data table Item data with type, name, schema, etc.
---@param connection table Connection context
---@return string? path Full qualified path or nil
local function build_item_path(item_data, connection)
  local item_type = item_data.type

  if item_type == "database" then
    -- Database: just the name
    return item_data.name or item_data.label

  elseif item_type == "schema" then
    -- Schema: database.schema
    local database = connection.database and connection.database.db_name or item_data.database
    local schema = item_data.name or item_data.schema
    if database and schema then
      return string.format("%s.%s", database, schema)
    end
    return schema

  elseif item_type == "table" or item_type == "view" then
    -- Table/View: schema.table (or database.schema.table if available)
    local schema = item_data.schema or "dbo"
    local name = item_data.name or item_data.table_name
    if schema and name then
      return string.format("%s.%s", schema, name)
    end
    return name

  elseif item_type == "column" then
    -- Column: table.column (or schema.table.column)
    local table_name = item_data.table_name or item_data.table
    local column_name = item_data.name or item_data.column_name

    if table_name and column_name then
      -- Include schema if available
      if item_data.schema then
        return string.format("%s.%s.%s", item_data.schema, table_name, column_name)
      else
        return string.format("%s.%s", table_name, column_name)
      end
    end
    return column_name

  elseif item_type == "procedure" or item_type == "function" then
    -- Procedure/Function: schema.name
    local schema = item_data.schema or "dbo"
    local name = item_data.name
    if schema and name then
      return string.format("%s.%s", schema, name)
    end
    return name

  end

  -- Fallback: just return name
  return item_data.name or item_data.label
end

---Record item selection in UsageTracker
---@param ctx table Completion context
---@param item table Completion item that was selected
local function record_item_selection(ctx, item)
  -- Get connection from context
  local connection = ctx.connection or ctx.provider_ctx.connection

  if not connection or not connection.connection_config then
    return  -- No connection available
  end

  -- Determine item type and path from item.data
  local item_data = item.data
  if not item_data or not item_data.type then
    return  -- No type information
  end

  -- Build full path for the item
  local item_path = build_item_path(item_data, connection)

  if not item_path then
    return  -- Could not build path
  end

  -- Record selection
  UsageTracker.record_selection(connection, item_data.type, item_path)

  -- Debug log
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log(string.format("[USAGE] Recorded selection: %s → %s",
      item_data.type, item_path))
  end
end

---Setup selection tracking for completion items
---Defers execution to check what was inserted after completion
---@param ctx table Completion context
---@param items table[] Array of completion items
local function setup_selection_tracker(ctx, items)
  -- Wrap in pcall for error handling
  local success, err = pcall(function()
    -- Only track if enabled in config
    local Config = require('ssns.config')
    local config = Config.get()

    if not config.completion or not config.completion.track_usage then
      return
    end

    -- Defer to next tick (after completion inserts text)
    vim.defer_fn(function()
      -- Another pcall inside the deferred function
      pcall(function()
        -- Get cursor position
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = vim.api.nvim_get_current_line()
        local col = cursor[2]

        -- Extract text before cursor
        local before_cursor = line:sub(1, col)

        -- Extract the last identifier/object that was inserted
        local inserted_text = extract_last_identifier(before_cursor)

        if not inserted_text or inserted_text == "" then
          return
        end

        -- Try to match against completion items
        for _, item in ipairs(items) do
          if matches_completion_item(inserted_text, item) then
            -- Found matching item - record selection
            record_item_selection(ctx, item)
            break
          end
        end
      end)
    end, 10)  -- 10ms delay
  end)

  if not success then
    -- Log error but don't notify user (silent failure for tracking)
    Debug.log("[USAGE] Selection tracking error: " .. tostring(err))
  end
end

-- ============================================================================
-- Source Class Definition
-- ============================================================================

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
    max_items = 0,               -- Limit completion items (0 = unlimited)
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

  -- Cancel any in-flight completion request
  if self._current_cancel_token then
    self._current_cancel_token:cancel("New completion request")
    Debug.log("[COMPLETION] Cancelled previous in-flight request")
  end

  -- Create new cancellation token for this request
  local Cancellation = require('ssns.async.cancellation')
  local cancel_token = Cancellation.create_token()
  self._current_cancel_token = cancel_token

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

  -- Check for cross-db schema completion early (TEST.█ pattern)
  -- Skip expensive pre_resolve_scope for this case
  local is_cross_db_schema = false
  local cross_db_target = nil  -- Store the target database for later use
  if context_result and context_result.potential_database and connection_ctx then
    local server = connection_ctx.server
    if server then
      local check_db = server:get_database(context_result.potential_database)
      if check_db then
        is_cross_db_schema = true
        cross_db_target = check_db
        Debug.log(string.format("[COMPLETION] Cross-db schema detected: %s - skipping pre_resolve_scope",
          context_result.potential_database))
      end
    end
  end

  -- Prepare context for providers (will add resolved_scope later if needed)
  local provider_ctx = {
    bufnr = ctx.bufnr,
    connection = connection_ctx,
    sql_context = context_result,
    cursor_pos = {context_result.line_num, context_result.col},
  }

  -- Pre-resolve all aliases and tables in scope to avoid repeated tree walks in providers
  -- Skip for cross-db schema completion (doesn't need resolved tables)
  -- Use async version for non-blocking completion
  if context_result and connection_ctx and not is_cross_db_schema then
    local Resolver = require('ssns.completion.metadata.resolver')

    -- Use async pre-resolution for non-blocking completion
    Resolver.pre_resolve_scope_async(context_result, connection_ctx, {
      timeout_ms = self.opts.timeout or 5000,
      cancel_token = cancel_token,
      on_complete = function(resolved_scope, err)
        -- Check if request was cancelled
        if cancel_token.is_cancelled then
          Debug.log("[COMPLETION] Request was cancelled, ignoring results")
          return
        end

        if resolved_scope then
          Debug.log(string.format("[COMPLETION] Pre-resolved scope (async): %d aliases, %d tables",
            vim.tbl_count(resolved_scope.resolved_aliases or {}),
            vim.tbl_count(resolved_scope.resolved_tables or {})))
          -- Add resolved_scope to context_result so providers can access it
          context_result.resolved_scope = resolved_scope
        end

        -- Continue with provider routing after pre-resolution
        self:_route_to_provider(context_result, provider_ctx, callback, start_time,
          is_cross_db_schema, cross_db_target, connection_ctx, cancel_token)
      end,
    })

    -- Return cancel function for blink.cmp
    return function()
      cancel_token:cancel("Completion cancelled by blink.cmp")
    end
  end

  -- For cross-db schema or no connection, route immediately (no pre-resolution needed)
  self:_route_to_provider(context_result, provider_ctx, callback, start_time,
    is_cross_db_schema, cross_db_target, connection_ctx, cancel_token)

  -- Return cancel function for blink.cmp
  return function()
    cancel_token:cancel("Completion cancelled by blink.cmp")
  end
end

---Route to appropriate provider based on context type (internal method)
---@param context_result table SQL context from detect_context
---@param provider_ctx table Provider context
---@param callback function blink.cmp callback
---@param start_time number Start time for performance tracking
---@param is_cross_db_schema boolean Whether this is cross-db schema completion
---@param cross_db_target table? Target database for cross-db completion
---@param connection_ctx table? Connection context
---@param cancel_token table? Cancellation token
function Source:_route_to_provider(context_result, provider_ctx, callback, start_time,
    is_cross_db_schema, cross_db_target, connection_ctx, cancel_token)

  -- Create callback wrapper to apply limits and track performance
  local wrapped_callback = function(items)
    -- Check if request was cancelled before delivering results
    if cancel_token and cancel_token.is_cancelled then
      Debug.log("[COMPLETION] Request cancelled, not delivering results")
      return
    end
    Debug.log(string.format("[COMPLETION] Provider returned %d items", items and #items or 0))
    -- Log first 5 item details for debugging
    if items and #items > 0 then
      local sample_count = math.min(5, #items)
      for i = 1, sample_count do
        local item = items[i]
        local item_type = item.data and item.data.type or "unknown"
        Debug.log(string.format("[COMPLETION]   Item %d: label=%s, detail=%s, type=%s",
          i, item.label or "nil", item.detail or "nil", item_type))
      end
      if #items > 5 then
        Debug.log(string.format("[COMPLETION]   ... and %d more items", #items - 5))
      end
    end

    -- Calculate elapsed time
    local end_time = vim.loop.hrtime()
    local elapsed_ms = (end_time - start_time) / 1e6

    -- Apply max_items limit
    if self.opts.max_items > 0 and #items > self.opts.max_items then
      items = vim.list_slice(items, 1, self.opts.max_items)
      Debug.log(string.format("[COMPLETION] Limited to %d items", #items))
    end

    -- Update performance stats if debug enabled
    if self.opts.debug then
      self:_update_stats(context_result.type, elapsed_ms, #items)
    end

    -- Setup selection tracking (deferred, non-blocking)
    if connection_ctx then
      local tracking_ctx = {
        connection = connection_ctx,
        provider_ctx = provider_ctx,
        sql_context = context_result,
      }
      setup_selection_tracker(tracking_ctx, items)
    end

    -- Return results via callback
    Debug.log(string.format("[COMPLETION] Calling blink callback with %d items", #items))
    callback({
      items = items,
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end

  -- Route to appropriate provider based on context type
  local Context = require('ssns.completion.statement_context')

  Debug.log(string.format("[COMPLETION] Routing to provider for context type: %s (mode: %s)",
    context_result.type, context_result.mode or "nil"))

  if context_result.type == Context.Type.TABLE then
    -- Cross-database schema completion ("TEST.█" pattern)
    if is_cross_db_schema and cross_db_target then
      Debug.log(string.format("[COMPLETION] Routing to SchemasProvider for cross-db: %s",
        context_result.potential_database))
      local SchemasProvider = require('ssns.completion.providers.schemas')
      SchemasProvider.get_completions(provider_ctx, wrapped_callback)
      return
    end

    -- Table/view/synonym completion (async to avoid blocking on database load)
    Debug.log("[COMPLETION] Calling TablesProvider (async)")
    local TablesProvider = require('ssns.completion.providers.tables')
    TablesProvider.get_completions_async(provider_ctx, {
      on_complete = function(items, _)
        wrapped_callback(items or {})
      end
    })

  elseif context_result.type == Context.Type.COLUMN then
    -- Column completion (async to avoid blocking on database load)
    Debug.log("[COMPLETION] Calling ColumnsProvider (async)")
    local ColumnsProvider = require('ssns.completion.providers.columns')
    ColumnsProvider.get_completions_async(provider_ctx, {
      on_complete = function(items, _)
        wrapped_callback(items or {})
      end
    })

  elseif context_result.type == Context.Type.PROCEDURE then
    Debug.log("[COMPLETION] Calling ProceduresProvider (async)")
    local ProceduresProvider = require('ssns.completion.providers.procedures')
    ProceduresProvider.get_completions_async(provider_ctx, {
      on_complete = function(items, _)
        wrapped_callback(items or {})
      end
    })

  elseif context_result.type == Context.Type.PARAMETER then
    Debug.log("[COMPLETION] Calling ParametersProvider")
    local ParametersProvider = require('ssns.completion.providers.parameters')
    ParametersProvider.get_completions(provider_ctx, wrapped_callback)

  elseif context_result.type == Context.Type.DATABASE then
    Debug.log("[COMPLETION] Calling DatabasesProvider (async)")
    local DatabasesProvider = require('ssns.completion.providers.databases')
    DatabasesProvider.get_completions_async(provider_ctx, {
      on_complete = function(items, _)
        wrapped_callback(items or {})
      end
    })

  elseif context_result.type == Context.Type.SCHEMA then
    Debug.log("[COMPLETION] Calling SchemasProvider (async)")
    local SchemasProvider = require('ssns.completion.providers.schemas')
    SchemasProvider.get_completions_async(provider_ctx, {
      on_complete = function(items, _)
        wrapped_callback(items or {})
      end
    })

  elseif context_result.type == Context.Type.KEYWORD then
    Debug.log("[COMPLETION] Calling KeywordsProvider + FunctionsProvider + SnippetsProvider")
    local KeywordsProvider = require('ssns.completion.providers.keywords')
    local FunctionsProvider = require('ssns.completion.providers.functions')
    local SnippetsProvider = require('ssns.completion.providers.snippets')

    local items = {}

    local keyword_success, keyword_items = pcall(KeywordsProvider._get_completions_impl, provider_ctx)
    if keyword_success and keyword_items then
      vim.list_extend(items, keyword_items)
    end

    local func_success, func_items = pcall(FunctionsProvider._get_completions_impl, provider_ctx)
    if func_success and func_items then
      vim.list_extend(items, func_items)
    end

    local snippet_success, snippet_items = pcall(SnippetsProvider._get_completions_impl, provider_ctx)
    if snippet_success and snippet_items then
      vim.list_extend(items, snippet_items)
    end

    wrapped_callback(items)

  else
    Debug.log(string.format("[COMPLETION] Unknown context type: %s, returning empty",
      tostring(context_result.type)))
    wrapped_callback({})
  end
end

---Detect SQL context from cursor position
---@param ctx table blink.cmp context
---@return table? context SQL context or nil if disabled
function Source:detect_context(ctx)
  local Context = require('ssns.completion.statement_context')

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
---@return table? connection { server: ServerClass, database: DbClass, connection_config: table }
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
    connection_config = server.connection_config,
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

-- Initialize UsageTracker on module load
local function init_usage_tracker()
  local Config = require('ssns.config')
  local config = Config.get()

  if config.completion and config.completion.track_usage then
    UsageTracker.init()
    Debug.log("[SOURCE] UsageTracker initialized")
  end
end

-- Call on module load
local init_success, init_err = pcall(init_usage_tracker)
if not init_success then
  Debug.log("[SOURCE] Failed to initialize UsageTracker: " .. tostring(init_err))
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
