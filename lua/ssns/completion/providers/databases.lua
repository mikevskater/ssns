---Database completion provider for SSNS IntelliSense
---Provides completion for database names (e.g., after USE keyword)
---@class DatabasesProvider
local DatabasesProvider = {}

---Get database completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function DatabasesProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return DatabasesProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify(
          string.format("[SSNS Completion] Databases provider error: %s", tostring(result)),
          vim.log.levels.ERROR
        )
      end
      callback({})
    end
  end)
end

---Internal implementation of database completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function DatabasesProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
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
  for _, db in ipairs(databases) do
    local item = Utils.format_database(db, {})
    table.insert(items, item)
  end

  -- Sort by database name (case-insensitive)
  table.sort(items, function(a, b)
    return a.label:lower() < b.label:lower()
  end)

  return items
end

return DatabasesProvider
