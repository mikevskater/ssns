---Table/View/Synonym completion provider for SSNS IntelliSense
---Provides completion suggestions for table, view, and synonym names in SQL queries
---@class TablesProvider
local TablesProvider = {}

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

  local items = {}

  -- Get database adapter to check features
  local adapter = database:get_adapter()

  -- Collect tables
  local tables = TablesProvider._collect_tables(database, show_schema_prefix)
  for _, item in ipairs(tables) do
    table.insert(items, item)
  end

  -- Collect views (if database supports them)
  if adapter.features and adapter.features.views then
    local views = TablesProvider._collect_views(database, show_schema_prefix)
    for _, item in ipairs(views) do
      table.insert(items, item)
    end
  end

  -- Collect synonyms (if database supports them)
  if adapter.features and adapter.features.synonyms then
    local synonyms = TablesProvider._collect_synonyms(database, show_schema_prefix)
    for _, item in ipairs(synonyms) do
      table.insert(items, item)
    end
  end

  -- Collect functions (if supported and they can be selected from)
  if adapter.features and adapter.features.functions then
    local functions = TablesProvider._collect_functions(database, show_schema_prefix)
    for _, item in ipairs(functions) do
      table.insert(items, item)
    end
  end

  -- Sort items by label (case-insensitive)
  table.sort(items, function(a, b)
    return a.label:lower() < b.label:lower()
  end)

  return items
end

---Collect table completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@return table[] items Array of CompletionItems
function TablesProvider._collect_tables(database, show_schema_prefix)
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
    -- Create completion item using Utils.format_table
    local item = Utils.format_table(table_obj, {
      show_schema = show_schema_prefix,
    })
    table.insert(items, item)
  end

  return items
end

---Collect view completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@return table[] items Array of CompletionItems
function TablesProvider._collect_views(database, show_schema_prefix)
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
    -- Create completion item using Utils.format_view
    local item = Utils.format_view(view_obj, {
      show_schema = show_schema_prefix,
    })
    table.insert(items, item)
  end

  return items
end

---Collect synonym completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@return table[] items Array of CompletionItems
function TablesProvider._collect_synonyms(database, show_schema_prefix)
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
    -- Create completion item using Utils.format_synonym
    local item = Utils.format_synonym(synonym_obj, {
      show_schema = show_schema_prefix,
    })
    table.insert(items, item)
  end

  return items
end

---Collect function completion items from database
---@param database DbClass Database object
---@param show_schema_prefix boolean Whether to show schema prefix
---@return table[] items Array of CompletionItems
function TablesProvider._collect_functions(database, show_schema_prefix)
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
    local item = Utils.format_procedure(func_obj, {
      show_schema = show_schema_prefix,
      priority = 3,  -- Lower priority than tables/views
      with_params = true,
    })
    table.insert(items, item)
  end

  return items
end

return TablesProvider
