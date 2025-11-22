---SSNS blink.cmp completion source
---Provides SQL IntelliSense for tables, columns, procedures, and keywords
---@class SsnsCompletionSource
local Source = {}

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
  -- Only enable for SQL file types
  local ft = vim.bo.filetype
  if not (ft == 'sql' or ft == 'mysql' or ft == 'plsql' or ft == 'pgsql') then
    return false
  end

  -- Check if completion is enabled in config
  local config = require('ssns.config').get()
  if config.completion and config.completion.enabled == false then
    return false
  end

  return true
end

---Get trigger characters for auto-completion
---@return string[] triggers Array of trigger characters
function Source:get_trigger_characters()
  return { '.', '[', ' ' }
end

---Main completion method (async)
---@param ctx table blink.cmp context { line: string, cursor: {row, col}, bounds: {start_col, end_col}, filetype: string, bufnr: number }
---@param callback function Callback function(response: { items: table[], is_incomplete_backward?: boolean, is_incomplete_forward?: boolean })
---@return function? cancel Optional cancellation function
function Source:get_completions(ctx, callback)
  -- Detect SQL context
  local context_result = self:detect_context(ctx)

  -- If context detection failed or disabled, return empty
  if not context_result or not context_result.should_complete then
    vim.schedule(function()
      callback({ items = {} })
    end)
    return
  end

  -- Get connection context for buffer
  local connection_ctx = self:get_connection(ctx.bufnr)

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

  -- Create callback wrapper to apply limits
  local wrapped_callback = function(items)
    -- Apply max_items limit
    if self.opts.max_items > 0 and #items > self.opts.max_items then
      items = vim.list_slice(items, 1, self.opts.max_items)
    end

    -- Return results via callback (async pattern)
    vim.schedule(function()
      callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    end)
  end

  -- Route to appropriate provider based on context type
  local Context = require('ssns.completion.context')

  if context_result.type == Context.Type.TABLE then
    -- Table/view/synonym completion (Phase 10.2)
    local TablesProvider = require('ssns.completion.providers.tables')
    TablesProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.COLUMN then
    -- Column completion (Phase 10.3 Week 2)
    local ColumnsProvider = require('ssns.completion.providers.columns')
    ColumnsProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.PROCEDURE then
    -- Procedure/function completion (Phase 10.6)
    local ProceduresProvider = require('ssns.completion.providers.procedures')
    ProceduresProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.PARAMETER then
    -- Parameter completion (Phase 10.6)
    local ParametersProvider = require('ssns.completion.providers.parameters')
    ParametersProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.DATABASE then
    -- Database completion
    local DatabasesProvider = require('ssns.completion.providers.databases')
    DatabasesProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.SCHEMA then
    -- Schema completion
    local SchemasProvider = require('ssns.completion.providers.schemas')
    SchemasProvider.get_completions(provider_ctx, wrapped_callback)
    return
  elseif context_result.type == Context.Type.KEYWORD then
    -- Keyword completion (Phase 10.7)
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

  if not db_key then
    -- No connection associated with buffer
    return nil
  end

  -- Parse db_key format: "server_name:database_name"
  local server_name, db_name = db_key:match("^([^:]+):(.+)$")

  if not server_name or not db_name then
    return nil
  end

  -- Find server and database in cache
  local server = Cache.find_server(server_name)
  if not server then
    return nil
  end

  local database = server:find_database(db_name)
  if not database then
    return nil
  end

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

return Source
