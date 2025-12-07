---Table/View/Synonym completion provider for SSNS IntelliSense
---Provides completion suggestions for table, view, and synonym names in SQL queries
---@class TablesProvider
local TablesProvider = {}

local UsageTracker = require('ssns.completion.usage_tracker')
local Config = require('ssns.config')

---Get usage weight for an item
---@param connection table Connection context
---@param item_type string Type ("table", "column", etc.)
---@param item_path string Full path to item
---@return number weight Usage weight (0 if not found or tracking disabled)
local function get_usage_weight(connection, item_type, item_path)
  local config = Config.get()

  -- If tracking disabled, return 0 (no weight)
  if not config.completion or not config.completion.track_usage then
    return 0
  end

  -- Get weight from UsageTracker
  local success, weight = pcall(function()
    return UsageTracker.get_weight(connection, item_type, item_path)
  end)

  if success then
    return weight or 0
  else
    return 0
  end
end

---Get table/view/synonym completions for the given context
---@param ctx table Context from source (has bufnr, connection info)
---@param callback function Callback(items)
function TablesProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return TablesProvider._get_completions_impl(ctx)
  end)

  -- Call callback directly (no vim.schedule needed - work is synchronous)
  if success then
    callback(result or {})
  else
    -- Log error in debug mode if available
    if vim.g.ssns_debug then
      vim.notify(
        string.format("[SSNS Completion] Tables provider error: %s", tostring(result)),
        vim.log.levels.ERROR
      )
    end
    callback({})
  end
end

---Internal implementation of completion retrieval
---@param ctx table Context from source
---@return table[] items Array of CompletionItems
function TablesProvider._get_completions_impl(ctx)
  local Cache = require('ssns.cache')
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local Debug = require('ssns.debug')

  -- Get connection information from context
  local connection_info = ctx.connection
  if not connection_info then
    return {}
  end

  local server = connection_info.server
  local database = connection_info.database

  -- Verify we have a valid, connected server
  if not server or not server:is_connected() then
    return {}
  end

  -- Verify we have a database
  if not database then
    return {}
  end

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Get show_schema_prefix option from config
  local show_schema_prefix = Config.ui and Config.ui.show_schema_prefix
  if show_schema_prefix == nil then
    show_schema_prefix = true -- Default to true
  end

  -- Get context information for qualification handling
  local sql_context = ctx.sql_context or {}
  local omit_schema = sql_context.omit_schema or false -- Don't include schema in insertText if already typed
  local filter_schema = sql_context.filter_schema -- Only show objects from this schema
  local filter_database = sql_context.filter_database -- Cross-database completion

  -- Debug logging for filter_schema troubleshooting
  local mode = sql_context.mode or "unknown"
  Debug.log(string.format("[TablesProvider] sql_context: mode=%s, filter_schema=%s, filter_database=%s, omit_schema=%s",
    mode, tostring(filter_schema), tostring(filter_database), tostring(omit_schema)))

  -- Resolve target database (for cross-db completion like TEST.dbo.█)
  local target_db = database
  if filter_database and server then
    target_db = server:get_database(filter_database)
    if target_db and not target_db.is_loaded then
      target_db:load()
    end
  end

  -- If we couldn't find the target database, return empty
  if not target_db then
    return {}
  end

  -- Determine what types to include based on context mode
  local include_tables = true
  local include_views = true
  local include_synonyms = true
  local include_functions = false  -- DEFAULT: Don't include functions in FROM/JOIN

  -- Adjust based on context mode
  -- Use string.sub for efficient prefix matching (replaces regex patterns)
  local mode_prefix_4 = mode:sub(1, 4)  -- Get first 4 chars for from/join checks
  local mode_prefix_6 = mode:sub(1, 6)  -- Get first 6 chars for insert/update/delete checks
  if mode_prefix_6 == "insert" or mode_prefix_6 == "update" or mode_prefix_6 == "delete" then
    -- DML statements: only tables (views/synonyms are read-only)
    include_views = false
    include_synonyms = false
    include_functions = false
  elseif mode_prefix_4 == "from" or mode_prefix_4 == "join" then
    -- FROM/JOIN (including from_qualified, join_qualified, etc.): tables, views, synonyms, AND table-valued functions
    include_functions = true
  elseif mode == "qualified_partial" or mode == "qualified_bracket" then
    -- Qualified context (schema.): include all queryable types
    include_functions = true
  end

  local items = {}

  -- Get database adapter to check features
  local adapter = target_db:get_adapter()

  -- In basic FROM/JOIN context (no qualification), also include databases and schemas
  -- This allows users to type "SELECT * FROM <db>." or "SELECT * FROM <schema>."
  local is_basic_from_join = (mode == "from" or mode == "join") and not filter_schema and not filter_database
  Debug.log(string.format("[TablesProvider] is_basic_from_join=%s (mode=%s, filter_schema=%s, filter_database=%s)",
    tostring(is_basic_from_join), mode, tostring(filter_schema), tostring(filter_database)))

  if is_basic_from_join then
    -- Include other databases from the server (for cross-db queries)
    local databases = TablesProvider._collect_databases(server)
    Debug.log(string.format("[TablesProvider] Adding %d databases (is_basic_from_join=true)", #databases))
    for _, item in ipairs(databases) do
      table.insert(items, item)
    end

    -- Include schemas from the current database (for qualified queries)
    local schemas = TablesProvider._collect_schemas(target_db)
    Debug.log(string.format("[TablesProvider] Adding %d schemas (is_basic_from_join=true)", #schemas))
    for _, item in ipairs(schemas) do
      table.insert(items, item)
    end
  else
    Debug.log("[TablesProvider] NOT adding databases/schemas (is_basic_from_join=false)")
  end

  -- Collect tables (if enabled)
  if include_tables then
    local tables = TablesProvider._collect_tables(target_db, show_schema_prefix, omit_schema, filter_schema)
    Debug.log(string.format("[TablesProvider] Collected %d tables (filter_schema=%s)", #tables, tostring(filter_schema)))
    for _, item in ipairs(tables) do
      table.insert(items, item)
    end
  end

  -- Collect views (if enabled and supported)
  if include_views and adapter.features and adapter.features.views then
    local views = TablesProvider._collect_views(target_db, show_schema_prefix, omit_schema, filter_schema)
    Debug.log(string.format("[TablesProvider] Collected %d views (filter_schema=%s)", #views, tostring(filter_schema)))
    for _, item in ipairs(views) do
      table.insert(items, item)
    end
  end

  -- Collect synonyms (if enabled and supported)
  if include_synonyms and adapter.features and adapter.features.synonyms then
    local synonyms = TablesProvider._collect_synonyms(target_db, show_schema_prefix, omit_schema, filter_schema)
    Debug.log(string.format("[TablesProvider] Collected %d synonyms (filter_schema=%s)", #synonyms, tostring(filter_schema)))
    for _, item in ipairs(synonyms) do
      table.insert(items, item)
    end
  end

  -- Collect functions (if enabled and supported)
  if include_functions and adapter.features and adapter.features.functions then
    local functions = TablesProvider._collect_functions(target_db, show_schema_prefix, omit_schema, filter_schema)
    Debug.log(string.format("[TablesProvider] Collected %d functions (filter_schema=%s)", #functions, tostring(filter_schema)))
    for _, item in ipairs(functions) do
      table.insert(items, item)
    end
  end

  -- Collect CTEs (Common Table Expressions) from the current query context
  -- CTEs should be available as table sources in FROM/JOIN clauses
  if sql_context.ctes then
    for cte_name, cte_info in pairs(sql_context.ctes) do
      table.insert(items, {
        label = cte_name,
        kind = Utils.CompletionItemKind.Module,  -- Use Module kind for CTEs (distinguish from tables)
        detail = "CTE",
        documentation = {
          kind = "markdown",
          value = string.format("**Common Table Expression**\n\nDefined in the WITH clause of the current query.\n\nColumns: %d", #(cte_info.columns or {})),
        },
        insertText = cte_name,
        filterText = cte_name,
        sortText = "00001_" .. cte_name,  -- Sort CTEs at the top since they're query-local
        data = {
          type = "cte",
          name = cte_name,
          is_cte = true,
        },
      })
    end
  end

  -- Collect temp tables from the current buffer context
  -- Temp tables should be available as table sources in FROM/JOIN clauses
  -- But NOT when completing schema-qualified names (e.g., dbo.█) since temp tables don't belong to schemas
  if sql_context.temp_tables and not filter_schema then
    for temp_name, temp_info in pairs(sql_context.temp_tables) do
      local temp_type = temp_info.is_global and "Global Temp Table" or "Temp Table"
      local icon = temp_info.is_global and "##" or "#"
      table.insert(items, {
        label = temp_name,
        kind = Utils.CompletionItemKind.Struct,  -- Use Struct kind for temp tables
        detail = temp_type,
        documentation = {
          kind = "markdown",
          value = string.format("**%s**\n\nDefined in the current buffer.\n\nColumns: %d", temp_type, #(temp_info.columns or {})),
        },
        insertText = temp_name,
        filterText = temp_name,
        sortText = "00002_" .. temp_name,  -- Sort temp tables after CTEs but before regular tables
        data = {
          type = "temp_table",
          name = temp_name,
          is_temp_table = true,
          is_global = temp_info.is_global,
        },
      })
    end
  end

  -- Inject usage weights into sortText for all items
  for idx, item in ipairs(items) do
    local item_data = item.data
    local item_path = nil

    -- Build full path based on item type
    if item_data.schema and item_data.name then
      item_path = string.format("%s.%s", item_data.schema, item_data.name)
    elseif item_data.name then
      item_path = item_data.name
    end

    if item_path then
      -- Get usage weight
      local weight = get_usage_weight(connection_info, item_data.type, item_path)

      -- Calculate priority (higher weight = lower sort value = sorts first)
      -- Priority ranges:
      --   0-4999: High usage items (weight-based)
      --   5000-9999: Low/no usage items (original order)
      local priority
      if weight > 0 then
        priority = math.max(0, 4999 - weight)  -- Higher weight = lower priority number
      else
        priority = 5000 + idx  -- No weight, use iteration order
      end

      -- Update sortText with new priority
      item.sortText = string.format("%05d_%s", priority, item.label)

      -- Store weight in data for debugging
      item.data.weight = weight
    end
  end

  return items
end

---Collect table completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@param omit_schema boolean Whether to omit schema from insertText (context-aware)
---@param filter_schema string? Only include tables from this schema
---@return table[] items Array of CompletionItems
function TablesProvider._collect_tables(database, show_schema_prefix, omit_schema, filter_schema)
  local Utils = require('ssns.completion.utils')
  local items = {}

  -- Get adapter for proper identifier quoting
  local adapter = database:get_adapter()

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local tables = database:get_tables(filter_schema)

  for _, table_obj in ipairs(tables) do
    -- Create completion item using Utils.format_table
    local item = Utils.format_table(table_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
      adapter = adapter,
    })
    table.insert(items, item)
  end

  return items
end

---Collect view completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@param omit_schema boolean Whether to omit schema from insertText (context-aware)
---@param filter_schema string? Only include views from this schema
---@return table[] items Array of CompletionItems
function TablesProvider._collect_views(database, show_schema_prefix, omit_schema, filter_schema)
  local Utils = require('ssns.completion.utils')
  local items = {}

  -- Get adapter for proper identifier quoting
  local adapter = database:get_adapter()

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local views = database:get_views(filter_schema)

  for _, view_obj in ipairs(views) do
    -- Create completion item using Utils.format_view
    local item = Utils.format_view(view_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
      adapter = adapter,
    })
    table.insert(items, item)
  end

  return items
end

---Collect synonym completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@param omit_schema boolean Whether to omit schema from insertText (context-aware)
---@param filter_schema string? Only include synonyms from this schema
---@return table[] items Array of CompletionItems
function TablesProvider._collect_synonyms(database, show_schema_prefix, omit_schema, filter_schema)
  local Utils = require('ssns.completion.utils')
  local items = {}

  -- Get adapter for proper identifier quoting
  local adapter = database:get_adapter()

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local synonyms = database:get_synonyms(filter_schema)

  for _, synonym_obj in ipairs(synonyms) do
    -- Create completion item using Utils.format_synonym
    local item = Utils.format_synonym(synonym_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
      adapter = adapter,
    })
    table.insert(items, item)
  end

  return items
end

---Collect function completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@param omit_schema boolean Whether to omit schema from insertText (context-aware)
---@param filter_schema string? Only include functions from this schema
---@return table[] items Array of CompletionItems
function TablesProvider._collect_functions(database, show_schema_prefix, omit_schema, filter_schema)
  local Utils = require('ssns.completion.utils')
  local items = {}

  if not database then
    return items
  end

  -- Get adapter for proper identifier quoting
  local adapter = database:get_adapter()

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local functions = database:get_functions(filter_schema)

  for _, func_obj in ipairs(functions) do
    -- Only include table-valued functions (skip scalar functions)
    if func_obj.is_table_valued and not func_obj:is_table_valued() then
      goto continue
    end

    local item = Utils.format_procedure(func_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
      priority = 3,  -- Lower priority than tables/views
      with_params = true,
      adapter = adapter,
    })
    table.insert(items, item)

    ::continue::
  end

  return items
end

---Collect database completion items from server (for cross-db queries)
---@param server table Server object
---@return table[] items Array of CompletionItems
function TablesProvider._collect_databases(server)
  local Utils = require('ssns.completion.utils')
  local items = {}

  if not server then
    return items
  end

  -- Use server accessor method
  local databases = server:get_databases()

  for _, db in ipairs(databases) do
    local item = Utils.format_database(db, {})
    table.insert(items, item)
  end

  return items
end

---Collect schema completion items from database (for qualified queries)
---@param database table Database object
---@return table[] items Array of CompletionItems
function TablesProvider._collect_schemas(database)
  local Utils = require('ssns.completion.utils')
  local items = {}

  if not database then
    return items
  end

  -- Get all schemas from database
  local schemas = database:get_schemas()

  if not schemas then
    return items
  end

  -- Format each schema as CompletionItem
  for _, schema in ipairs(schemas) do
    local item = Utils.format_schema(schema, {})
    table.insert(items, item)
  end

  return items
end

return TablesProvider
