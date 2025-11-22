---Schema completion provider for SSNS IntelliSense
---Provides completion for schema names (e.g., dbo., public.)
---@class SchemasProvider
local SchemasProvider = {}

---Get schema completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function SchemasProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return SchemasProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify(
          string.format("[SSNS Completion] Schemas provider error: %s", tostring(result)),
          vim.log.levels.ERROR
        )
      end
      callback({})
    end
  end)
end

---Internal implementation of schema completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function SchemasProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
  local connection = ctx.connection

  if not connection or not connection.database then
    return {}
  end

  local database = connection.database

  -- Verify we have a valid database
  if not database then
    return {}
  end

  local items = {}

  -- Get all schemas from database
  local schemas = database:get_schemas()

  if not schemas then
    return {}
  end

  -- Format each schema as CompletionItem
  for _, schema in ipairs(schemas) do
    local item = Utils.format_schema(schema, {})
    table.insert(items, item)
  end

  -- Sort by schema name (case-insensitive)
  table.sort(items, function(a, b)
    return a.label:lower() < b.label:lower()
  end)

  return items
end

return SchemasProvider
