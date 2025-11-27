---Column completion provider for SSNS IntelliSense
---Provides context-aware column completions with alias resolution
---@class ColumnsProvider
local ColumnsProvider = {}

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

---Resolve table reference to full path for weight lookup
---@param table_ref string Table reference (could be alias, name, etc.)
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@param resolved_scope table? Pre-resolved scope from source
---@return string? path Full path (e.g., "dbo.Employees") or nil
local function resolve_table_path(table_ref, connection, context, resolved_scope)
  if not table_ref then
    return nil
  end

  -- Try to resolve via Resolver
  local success, result = pcall(function()
    local Resolver = require('ssns.completion.metadata.resolver')

    -- Try pre-resolved scope first
    local table_obj = nil
    if resolved_scope then
      table_obj = Resolver.get_resolved(resolved_scope, table_ref)
    end
    if not table_obj then
      table_obj = Resolver.resolve_table(table_ref, connection, context)
    end

    if table_obj then
      local schema = table_obj.schema or table_obj.schema_name
      local name = table_obj.name or table_obj.table_name

      if schema and name then
        return string.format("%s.%s", schema, name)
      elseif name then
        return name
      end
    end

    return nil
  end)

  if success and result then
    return result
  end

  -- Fallback: assume it's already a qualified name
  return table_ref
end

---Get column completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function ColumnsProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return ColumnsProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify(
          string.format("[SSNS] Column provider error: %s", tostring(result)),
          vim.log.levels.ERROR
        )
      end
      callback({})
    end
  end)
end

---Internal implementation of column completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ColumnsProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection
  local bufnr = ctx.bufnr

  -- Check if we have a valid connection
  if not connection or not connection.database then
    return {}
  end

  -- Route based on context mode
  if sql_context.mode == "qualified" or
     sql_context.mode == "select_qualified" or
     sql_context.mode == "where_qualified" then
    -- Pattern: table.| or alias.|
    local Debug = require('ssns.debug')
    Debug.log(string.format("[COLUMNS] Routing mode '%s' to _get_qualified_columns", sql_context.mode or "nil"))
    return ColumnsProvider._get_qualified_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "select" or sql_context.mode == "where" or
         sql_context.mode == "order_by" or sql_context.mode == "group_by" or
         sql_context.mode == "set" then
    -- Pattern: SELECT | or WHERE | or UPDATE SET | (show columns from all tables in query)
    return ColumnsProvider._get_all_columns_from_query(connection, sql_context)

  elseif sql_context.mode == "qualified_bracket" then
    -- Pattern: [schema].[table].| or [database].|
    return ColumnsProvider._get_qualified_bracket_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "insert_columns" then
    -- Pattern: INSERT INTO table (| - show columns from target table
    return ColumnsProvider._get_insert_columns(connection, sql_context)

  else
    return {}
  end
end

---Get columns for qualified reference (table.| or alias.|)
---@param sql_context table SQL context { table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@return table[] items CompletionItems
function ColumnsProvider._get_qualified_columns(sql_context, connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get table reference (could be alias or table name)
  local reference = sql_context.table_ref
  if not reference then
    return {}
  end

  -- Try CTE columns first using pre-built context
  if context and context.ctes then
    local cte_info = context.ctes[reference] or context.ctes[reference:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      local items = {}
      for _, col_name in ipairs(cte_info.columns) do
        table.insert(items, {
          label = col_name,
          kind = vim.lsp.protocol.CompletionItemKind.Field,
          detail = "CTE column",
          insertText = col_name,
        })
      end
      return items
    end
  end

  -- Fall back to database table lookup
  -- Try pre-resolved scope first, then on-demand resolution
  local table_obj = nil
  if sql_context.resolved_scope then
    table_obj = Resolver.get_resolved(sql_context.resolved_scope, reference)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(reference, connection, context)
  end

  if not table_obj then
    return {}
  end

  -- Get columns
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {}
  end

  -- Format as CompletionItems
  local items = {}

  -- Resolve table path for weight lookup
  local table_path = resolve_table_path(reference, connection, context, sql_context.resolved_scope)

  for _, col in ipairs(columns) do
    local item = Utils.format_column(col, {
      show_type = true,
      show_nullable = true,
    })

    -- Inject usage weight if we have a table path
    if table_path then
      local col_name = col.name or col.column_name
      if col_name then
        -- Build full column path: table.column
        local column_path = string.format("%s.%s", table_path, col_name)

        -- Get weight for THIS SPECIFIC column in THIS SPECIFIC table
        local weight = get_usage_weight(connection, "column", column_path)

        -- Priority calculation:
        --   0-999: Primary key columns (highest priority)
        --   1000-4999: Frequently used columns (weight-based)
        --   5000-9999: Rarely used columns (ordinal position)
        local is_pk = col.is_primary_key or col.is_pk
        local ordinal = col.ordinal_position or 999
        local priority

        if is_pk then
          priority = 100 - math.min(weight, 99)  -- PK columns always at top
        elseif weight > 0 then
          priority = 1000 + math.max(0, 3999 - weight)
        else
          priority = 5000 + ordinal
        end

        -- Update sortText with new priority
        item.sortText = string.format("%05d_%04d_%s", priority, ordinal, col_name)

        -- Store weight in data for debugging
        item.data.weight = weight
        item.data.table_path = table_path
      end
    end

    table.insert(items, item)
  end

  return items
end

---Get columns from all tables in query (for SELECT, WHERE, ORDER BY, GROUP BY)
---@param connection table Connection context
---@param context table Pre-built context with tables_in_scope
---@return table[] items CompletionItems
function ColumnsProvider._get_all_columns_from_query(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get all tables from query using pre-built context
  local tables = Resolver.resolve_all_tables_in_query(connection, context)
  if not tables or #tables == 0 then
    return {}
  end

  -- Collect columns from all tables
  local items = {}
  local seen_columns = {} -- Deduplicate column names
  local column_weights = {} -- Track max weight per column name

  for _, table_obj in ipairs(tables) do
    local columns = Resolver.get_columns(table_obj, connection)

    -- Build table path for weight lookup
    local schema = table_obj.schema or table_obj.schema_name
    local name = table_obj.name or table_obj.table_name or table_obj.view_name
    local table_path = nil
    if schema and name then
      table_path = string.format("%s.%s", schema, name)
    elseif name then
      table_path = name
    end

    for _, col in ipairs(columns) do
      local col_name = col.name or col.column_name

      -- Only add if not already seen (deduplicate)
      if col_name and not seen_columns[col_name:lower()] then
        seen_columns[col_name:lower()] = true

        local item = Utils.format_column(col, {
          show_type = true,
          show_nullable = true,
        })

        -- Add table name to detail to disambiguate
        local table_name = table_obj.name or table_obj.table_name or table_obj.view_name
        if table_name then
          local original_detail = item.detail or ""
          item.detail = string.format("%s (%s)", original_detail, table_name)
        end

        -- Get weight for this column (use max weight across all tables)
        local weight = 0
        if table_path then
          local column_path = string.format("%s.%s", table_path, col_name)
          weight = get_usage_weight(connection, "column", column_path)
        end

        -- Track max weight for this column name
        column_weights[col_name:lower()] = math.max(column_weights[col_name:lower()] or 0, weight)

        -- Store weight in data
        item.data.weight = weight

        table.insert(items, item)
      end
    end
  end

  -- Apply weight-based sorting to deduplicated columns
  for _, item in ipairs(items) do
    local col_name = item.label
    local weight = column_weights[col_name:lower()] or 0
    local is_pk = item.data.is_primary_key
    local ordinal = 999  -- Default ordinal for deduplicated columns

    local priority
    if is_pk then
      priority = 100 - math.min(weight, 99)
    elseif weight > 0 then
      priority = 1000 + math.max(0, 3999 - weight)
    else
      priority = 5000 + ordinal
    end

    item.sortText = string.format("%05d_%04d_%s", priority, ordinal, col_name)
  end

  return items
end

---Get columns for bracketed qualified reference ([schema].[table].|)
---@param sql_context table SQL context { schema: string, table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@return table[] items CompletionItems
function ColumnsProvider._get_qualified_bracket_columns(sql_context, connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Build qualified reference from schema and table_ref
  local reference
  if sql_context.schema and sql_context.table_ref then
    reference = string.format("%s.%s", sql_context.schema, sql_context.table_ref)
  elseif sql_context.table_ref then
    reference = sql_context.table_ref
  else
    return {}
  end

  -- Try CTE columns first using pre-built context
  if context and context.ctes then
    local cte_info = context.ctes[reference] or context.ctes[reference:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      local items = {}
      for _, col_name in ipairs(cte_info.columns) do
        table.insert(items, {
          label = col_name,
          kind = vim.lsp.protocol.CompletionItemKind.Field,
          detail = "CTE column",
          insertText = col_name,
        })
      end
      return items
    end
  end

  -- Fall back to database table lookup
  -- Try pre-resolved scope first, then on-demand resolution
  local table_obj = nil
  if sql_context.resolved_scope then
    table_obj = Resolver.get_resolved(sql_context.resolved_scope, reference)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(reference, connection, context)
  end

  if not table_obj then
    return {}
  end

  -- Get columns
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {}
  end

  -- Format as CompletionItems
  local items = {}

  -- Resolve table path for weight lookup
  local table_path = resolve_table_path(reference, connection, context, sql_context.resolved_scope)

  for _, col in ipairs(columns) do
    local item = Utils.format_column(col, {
      show_type = true,
      show_nullable = true,
    })

    -- Inject usage weight if we have a table path
    if table_path then
      local col_name = col.name or col.column_name
      if col_name then
        -- Build full column path: table.column
        local column_path = string.format("%s.%s", table_path, col_name)

        -- Get weight for THIS SPECIFIC column in THIS SPECIFIC table
        local weight = get_usage_weight(connection, "column", column_path)

        -- Priority calculation (same as qualified columns)
        local is_pk = col.is_primary_key or col.is_pk
        local ordinal = col.ordinal_position or 999
        local priority

        if is_pk then
          priority = 100 - math.min(weight, 99)
        elseif weight > 0 then
          priority = 1000 + math.max(0, 3999 - weight)
        else
          priority = 5000 + ordinal
        end

        -- Update sortText with new priority
        item.sortText = string.format("%05d_%04d_%s", priority, ordinal, col_name)

        -- Store weight in data for debugging
        item.data.weight = weight
        item.data.table_path = table_path
      end
    end

    table.insert(items, item)
  end

  return items
end

---Get columns for INSERT column list: INSERT INTO table (|col1, col2)
---@param connection table Connection context
---@param context table SQL context with chunk and resolved_scope
---@return table[] items CompletionItems
function ColumnsProvider._get_insert_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get INSERT target table from chunk.tables (first table in INSERT statement)
  if not context.chunk or not context.chunk.tables or #context.chunk.tables == 0 then
    return {}
  end

  local target_table = context.chunk.tables[1]  -- INSERT target is always first
  local table_name = target_table.name or target_table

  -- Resolve to actual table object
  local table_obj = nil
  if context.resolved_scope then
    table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(table_name, connection, context)
  end

  if not table_obj then
    return {}
  end

  -- Get columns
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {}
  end

  -- Format as CompletionItems
  local items = {}

  for _, col in ipairs(columns) do
    local item = Utils.format_column(col, {
      show_type = true,
      show_nullable = true,
    })

    -- Mark identity/computed columns with warning
    if col.is_identity then
      item.detail = (item.detail or "") .. " [IDENTITY]"
    end
    if col.is_computed then
      item.detail = (item.detail or "") .. " [COMPUTED]"
    end

    table.insert(items, item)
  end

  return items
end

return ColumnsProvider
