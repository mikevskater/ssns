---Column completion provider for SSNS IntelliSense
---Provides context-aware column completions with alias resolution
---@class ColumnsProvider
local ColumnsProvider = {}

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
  if sql_context.mode == "qualified" then
    -- Pattern: table.| or alias.|
    return ColumnsProvider._get_qualified_columns(sql_context, connection, bufnr)

  elseif sql_context.mode == "select" or sql_context.mode == "where" or
         sql_context.mode == "order_by" or sql_context.mode == "group_by" then
    -- Pattern: SELECT | or WHERE | (show columns from all tables in query)
    return ColumnsProvider._get_all_columns_from_query(connection, bufnr)

  elseif sql_context.mode == "qualified_bracket" then
    -- Pattern: [schema].[table].| or [database].|
    return ColumnsProvider._get_qualified_bracket_columns(sql_context, connection, bufnr)

  else
    return {}
  end
end

---Get columns for qualified reference (table.| or alias.|)
---@param sql_context table SQL context { table_ref: string, ... }
---@param connection table Connection context
---@param bufnr number Buffer number
---@return table[] items CompletionItems
function ColumnsProvider._get_qualified_columns(sql_context, connection, bufnr)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get table reference (could be alias or table name)
  local reference = sql_context.table_ref
  if not reference then
    return {}
  end

  -- Resolve to actual table object
  local table_obj = Resolver.resolve_table(reference, connection, bufnr)
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
    table.insert(items, item)
  end

  return items
end

---Get columns from all tables in query (for SELECT, WHERE, ORDER BY, GROUP BY)
---@param connection table Connection context
---@param bufnr number Buffer number
---@return table[] items CompletionItems
function ColumnsProvider._get_all_columns_from_query(connection, bufnr)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get all tables from query
  local tables = Resolver.resolve_all_tables_in_query(bufnr, connection)
  if not tables or #tables == 0 then
    return {}
  end

  -- Collect columns from all tables
  local items = {}
  local seen_columns = {} -- Deduplicate column names

  for _, table_obj in ipairs(tables) do
    local columns = Resolver.get_columns(table_obj, connection)
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

        table.insert(items, item)
      end
    end
  end

  return items
end

---Get columns for bracketed qualified reference ([schema].[table].|)
---@param sql_context table SQL context { schema: string, table_ref: string, ... }
---@param connection table Connection context
---@param bufnr number Buffer number
---@return table[] items CompletionItems
function ColumnsProvider._get_qualified_bracket_columns(sql_context, connection, bufnr)
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

  -- Resolve to actual table object
  local table_obj = Resolver.resolve_table(reference, connection, bufnr)
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
    table.insert(items, item)
  end

  return items
end

return ColumnsProvider
