---Schema completion provider for SSNS IntelliSense
---Provides completion for schema names (e.g., dbo., public.)
---@class SchemasProvider
local SchemasProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
SchemasProvider.get_completions = BaseProvider.create_safe_wrapper(SchemasProvider, "Schemas", false)

---Internal implementation of schema completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function SchemasProvider._get_completions_impl(ctx)
  local Utils = require('ssns.completion.utils')
  local Debug = require('ssns.debug')
  local connection = ctx.connection

  Debug.log("[SchemasProvider] _get_completions_impl called")

  if not connection or not connection.database then
    Debug.log("[SchemasProvider] No connection or database, returning empty")
    return {}
  end

  local server = connection.server
  local database = connection.database

  Debug.log(string.format("[SchemasProvider] connection.database=%s, server=%s",
    database and (database.db_name or database.name) or "nil",
    server and server.name or "nil"))

  -- Check if we need to get schemas from a different database (cross-db)
  local sql_context = ctx.sql_context or {}
  local filter_database = sql_context.filter_database
  local potential_database = sql_context.potential_database

  Debug.log(string.format("[SchemasProvider] filter_database=%s, potential_database=%s",
    filter_database or "nil", potential_database or "nil"))

  -- Resolve target database
  -- For "TEST.█" pattern, potential_database contains the database name
  local target_db = database
  local target_db_name = filter_database or potential_database
  if target_db_name and server then
    local check_db = server:get_database(target_db_name)
    Debug.log(string.format("[SchemasProvider] Looked up database '%s', found=%s",
      target_db_name, check_db and "yes" or "no"))
    if check_db then
      target_db = check_db
      -- NOTE: Don't call target_db:load() here - it loads all objects which is slow
      -- get_schemas() will only load schema names (lightweight)
    end
  end

  -- Verify we have a valid database
  if not target_db then
    Debug.log("[SchemasProvider] No target_db, returning empty")
    return {}
  end

  local items = {}

  -- Get all schemas from target database
  Debug.log(string.format("[SchemasProvider] Getting schemas from '%s'",
    target_db.db_name or target_db.name or "unknown"))
  local schemas = target_db:get_schemas()
  Debug.log(string.format("[SchemasProvider] Got %d schemas", schemas and #schemas or 0))

  if not schemas then
    return {}
  end

  -- Format each schema as CompletionItem
  for idx, schema in ipairs(schemas) do
    local item = Utils.format_schema(schema, {})

    -- Get schema name for weight lookup
    local schema_name = schema.name or schema.schema_name

    if schema_name and connection.database then
      -- Build schema path: database.schema
      local db_name = connection.database.name or connection.database.db_name or connection.database.database_name
      local schema_path = db_name and string.format("%s.%s", db_name, schema_name) or schema_name

      -- Get weight using BaseProvider
      local weight = BaseProvider.get_usage_weight(connection, "schema", schema_path)

      -- Priority calculation with special handling for system schemas
      local priority
      if weight > 0 then
        priority = BaseProvider.calculate_priority(weight, idx)
      else
        -- Default schemas (dbo, sys) get special treatment
        if schema_name == "dbo" then
          priority = 4000  -- dbo always high priority
        elseif schema_name:match("^sys") then
          priority = 8000  -- sys schemas lower priority
        else
          priority = 5000 + idx
        end
      end

      -- Update sortText
      item.sortText = BaseProvider.format_sort_text(priority, schema_name)

      -- Store weight in data for debugging
      item.data.weight = weight
    end

    table.insert(items, item)
  end

  Debug.log(string.format("[SchemasProvider] Returning %d items", #items))
  return items
end

return SchemasProvider
