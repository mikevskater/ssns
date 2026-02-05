---Database completion provider for SSNS IntelliSense
---Provides completion for database names (e.g., after USE keyword)
---@class DatabasesProvider
local DatabasesProvider = {}

local BaseProvider = require('nvim-ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
-- Note: uses vim.schedule (true) for async callback delivery
DatabasesProvider.get_completions = BaseProvider.create_safe_wrapper(DatabasesProvider, "Databases", true)

---Internal implementation of database completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function DatabasesProvider._get_completions_impl(ctx)
  local Utils = require('nvim-ssns.completion.utils')
  local connection = ctx.connection

  if not connection or not connection.server then
    return {}
  end

  local server = connection.server

  -- Verify we have a valid, connected server
  if not server:is_connected() then
    return {}
  end

  local items = {}

  -- Get all databases from server
  local databases = server:get_databases()

  if not databases then
    return {}
  end

  -- Format each database as CompletionItem
  for idx, db in ipairs(databases) do
    local item = Utils.format_database(db, {})

    -- Get database name for weight lookup
    local db_name = db.name or db.db_name or db.database_name

    if db_name then
      -- Apply usage weight using BaseProvider
      BaseProvider.apply_usage_weight(item, connection, "database", db_name, idx)
    end

    table.insert(items, item)
  end

  return items
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class DatabasesProviderAsyncOpts
---@field on_complete fun(items: table[], error: string?)? Completion callback

---Get database completions asynchronously
---@param ctx table Context { bufnr, connection, sql_context }
---@param opts DatabasesProviderAsyncOpts? Options with on_complete callback
function DatabasesProvider.get_completions_async(ctx, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  -- Databases are already cached on server, just schedule sync impl
  vim.schedule(function()
    local success, result = pcall(function()
      return DatabasesProvider._get_completions_impl(ctx)
    end)
    if success then
      on_complete(result or {}, nil)
    else
      on_complete({}, tostring(result))
    end
  end)
end

return DatabasesProvider
