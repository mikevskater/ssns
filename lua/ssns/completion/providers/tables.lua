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

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
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
  end)
end

---Internal implementation of completion retrieval
---@param ctx table Context from source
---@return table[] items Array of CompletionItems
function TablesProvider._get_completions_impl(ctx)
  local Cache = require('ssns.cache')
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()

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

  local items = {}

  -- Get database adapter to check features
  local adapter = database:get_adapter()

  -- Collect tables
  local tables = TablesProvider._collect_tables(database, show_schema_prefix, omit_schema, filter_schema)
  for _, item in ipairs(tables) do
    table.insert(items, item)
  end

  -- Collect views (if database supports them)
  if adapter.features and adapter.features.views then
    local views = TablesProvider._collect_views(database, show_schema_prefix, omit_schema, filter_schema)
    for _, item in ipairs(views) do
      table.insert(items, item)
    end
  end

  -- Collect synonyms (if database supports them)
  if adapter.features and adapter.features.synonyms then
    local synonyms = TablesProvider._collect_synonyms(database, show_schema_prefix, omit_schema, filter_schema)
    for _, item in ipairs(synonyms) do
      table.insert(items, item)
    end
  end

  -- Collect functions (if supported and they can be selected from)
  if adapter.features and adapter.features.functions then
    local functions = TablesProvider._collect_functions(database, show_schema_prefix, omit_schema, filter_schema)
    for _, item in ipairs(functions) do
      table.insert(items, item)
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

  -- Find the TABLES group in database children
  local tables_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "tables_group" then
      tables_group = child
      break
    end
  end

  if not tables_group then
    return items
  end

  -- Iterate through tables in the group
  for _, table_obj in ipairs(tables_group.children) do
    -- Filter by schema if specified
    if filter_schema then
      local obj_schema = (table_obj.schema or table_obj.schema_name or ""):lower()
      if obj_schema ~= filter_schema:lower() then
        goto continue
      end
    end

    -- Create completion item using Utils.format_table
    local item = Utils.format_table(table_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
    })
    table.insert(items, item)

    ::continue::
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

  -- Find the VIEWS group in database children
  local views_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "views_group" then
      views_group = child
      break
    end
  end

  if not views_group then
    return items
  end

  -- Iterate through views in the group
  for _, view_obj in ipairs(views_group.children) do
    -- Filter by schema if specified
    if filter_schema then
      local obj_schema = (view_obj.schema or view_obj.schema_name or ""):lower()
      if obj_schema ~= filter_schema:lower() then
        goto continue
      end
    end

    -- Create completion item using Utils.format_view
    local item = Utils.format_view(view_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
    })
    table.insert(items, item)

    ::continue::
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

  -- Find the SYNONYMS group in database children
  local synonyms_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "synonyms_group" then
      synonyms_group = child
      break
    end
  end

  if not synonyms_group then
    return items
  end

  -- Iterate through synonyms in the group
  for _, synonym_obj in ipairs(synonyms_group.children) do
    -- Filter by schema if specified
    if filter_schema then
      local obj_schema = (synonym_obj.schema or synonym_obj.schema_name or ""):lower()
      if obj_schema ~= filter_schema:lower() then
        goto continue
      end
    end

    -- Create completion item using Utils.format_synonym
    local item = Utils.format_synonym(synonym_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
    })
    table.insert(items, item)

    ::continue::
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

  if not database or not database.children then
    return items
  end

  -- Find the Functions group in database children
  local functions_group = nil
  for _, child in ipairs(database.children) do
    if child.object_type == "functions_group" then
      functions_group = child
      break
    end
  end

  if not functions_group or not functions_group.children then
    return items
  end

  -- Collect all function objects
  for _, func_obj in ipairs(functions_group.children) do
    -- Filter by schema if specified
    if filter_schema then
      local obj_schema = (func_obj.schema or func_obj.schema_name or ""):lower()
      if obj_schema ~= filter_schema:lower() then
        goto continue
      end
    end

    local item = Utils.format_procedure(func_obj, {
      show_schema = show_schema_prefix,
      omit_schema = omit_schema,
      priority = 3,  -- Lower priority than tables/views
      with_params = true,
    })
    table.insert(items, item)

    ::continue::
  end

  return items
end

return TablesProvider
