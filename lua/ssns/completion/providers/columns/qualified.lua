---Qualified column completion handlers
---Handles table.| and alias.| patterns, including CTEs, temp tables, and subqueries
---@class ColumnsQualified
local M = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

---Get columns for qualified reference (table.| or alias.|)
---@param sql_context table SQL context { table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@return table[] items CompletionItems
function M.get_qualified_columns(sql_context, connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')
  local ColumnsProvider = require('ssns.completion.providers.columns')

  -- Get table reference (could be alias or table name)
  local reference = sql_context.table_ref
  if not reference then
    return {}
  end

  -- Try CTE columns first using pre-built context
  if context and context.ctes then
    -- Reference could be CTE name directly or an alias to a CTE
    local cte_name = reference
    -- If reference is an alias, resolve it to the actual table/CTE name
    if context.aliases and context.aliases[reference:lower()] then
      cte_name = context.aliases[reference:lower()]
    end
    local cte_info = context.ctes[cte_name] or context.ctes[cte_name:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      -- Expand star columns (SELECT * in CTE) to actual columns from source table
      -- Pass context.ctes for CTE-to-CTE star expansion
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(cte_info.columns, connection, context.ctes, cte_info.tables)
      local items = {}
      for _, col_info in ipairs(expanded_columns) do
        -- CTE columns are ColumnInfo objects with a 'name' property
        local col_name = type(col_info) == "table" and col_info.name or col_info
        if col_name and col_name ~= "*" then  -- Skip unexpanded stars
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = "CTE column",
            insertText = col_name,
          })
        end
      end
      return items
    end
  end

  -- Try temp table columns using pre-built context
  if context and context.temp_tables then
    -- Reference could be temp table name directly (#TempName) or an alias
    local temp_name = reference
    -- If reference is an alias, resolve it to the actual table name
    if context.aliases and context.aliases[reference:lower()] then
      temp_name = context.aliases[reference:lower()]
    end
    local temp_info = context.temp_tables[temp_name] or context.temp_tables[temp_name:lower()]
    if temp_info and temp_info.columns and #temp_info.columns > 0 then
      -- Expand star columns if present
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(temp_info.columns, connection)
      local items = {}
      for _, col_info in ipairs(expanded_columns) do
        local col_name = type(col_info) == "table" and col_info.name or col_info
        local data_type = type(col_info) == "table" and col_info.data_type or nil
        if col_name and col_name ~= "*" then
          local detail = data_type and ("Temp table column - " .. data_type) or "Temp table column"
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = detail,
            insertText = col_name,
            data = {
              type = "column",
              name = col_name,
              data_type = data_type,
              is_temp_table = true,
            },
          })
        end
      end
      return items
    end
  end

  -- Try subquery/derived table columns from tables_in_scope
  if context and context.tables_in_scope then
    for _, table_info in ipairs(context.tables_in_scope) do
      if table_info.is_subquery then
        local sq_name = table_info.name or table_info.alias
        if sq_name and sq_name:lower() == reference:lower() then
          local sq_columns = table_info.columns or {}
          -- Expand star columns (SELECT * in subquery) to actual columns from source table
          local StatementCache = require('ssns.completion.statement_cache')
          local expanded_columns = StatementCache.expand_star_columns(sq_columns, connection)
          local items = {}
          for _, col_info in ipairs(expanded_columns) do
            local col_name = type(col_info) == "table" and col_info.name or col_info
            if col_name and col_name ~= "*" then  -- Skip unexpanded stars
              table.insert(items, {
                label = col_name,
                kind = vim.lsp.protocol.CompletionItemKind.Field,
                detail = "Derived table column",
                insertText = col_name,
              })
            end
          end
          return items
        end
      end
    end
  end

  -- Try table-valued function (TVF) columns from tables_in_scope
  if context and context.tables_in_scope then
    for _, table_info in ipairs(context.tables_in_scope) do
      if table_info.is_tvf then
        local tvf_alias = table_info.alias or table_info.name
        if tvf_alias and tvf_alias:lower() == reference:lower() then
          -- Look up TVF columns from database metadata
          local tvf_columns = Resolver.resolve_tvf_columns(
            table_info.function_name or table_info.name,
            table_info.schema,
            connection
          )
          if tvf_columns and #tvf_columns > 0 then
            local items = {}
            for _, col in ipairs(tvf_columns) do
              local col_name = col.name or col.column_name
              local data_type = col.data_type
              local detail = data_type and ("TVF column - " .. data_type) or "TVF column"
              table.insert(items, {
                label = col_name,
                kind = vim.lsp.protocol.CompletionItemKind.Field,
                detail = detail,
                insertText = col_name,
                data = {
                  type = "column",
                  name = col_name,
                  data_type = data_type,
                  is_tvf = true,
                },
              })
            end
            return items
          end
        end
      end
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
  local table_path = ColumnsProvider.resolve_table_path(reference, connection, context, sql_context.resolved_scope)

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
        local weight = BaseProvider.get_usage_weight(connection, "column", column_path)

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

---Get columns for bracketed qualified reference ([schema].[table].|)
---@param sql_context table SQL context { schema: string, table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@return table[] items CompletionItems
function M.get_qualified_bracket_columns(sql_context, connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')
  local ColumnsProvider = require('ssns.completion.providers.columns')

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
    -- Reference could be CTE name directly or an alias to a CTE
    local cte_name = reference
    -- If reference is an alias, resolve it to the actual table/CTE name
    if context.aliases and context.aliases[reference:lower()] then
      cte_name = context.aliases[reference:lower()]
    end
    local cte_info = context.ctes[cte_name] or context.ctes[cte_name:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      local items = {}
      for _, col_info in ipairs(cte_info.columns) do
        -- CTE columns are ColumnInfo objects with a 'name' property
        local col_name = type(col_info) == "table" and col_info.name or col_info
        if col_name then
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = "CTE column",
            insertText = col_name,
          })
        end
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
  local table_path = ColumnsProvider.resolve_table_path(reference, connection, context, sql_context.resolved_scope)

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
        local weight = BaseProvider.get_usage_weight(connection, "column", column_path)

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

-- ============================================================================
-- Async Methods
-- ============================================================================

---Get columns for qualified reference asynchronously (table.| or alias.|)
---Uses Resolver.get_columns_async for non-blocking column fetch
---@param sql_context table SQL context { table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@param opts table? Options with on_complete callback
function M.get_qualified_columns_async(sql_context, connection, context, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')
  local ColumnsProvider = require('ssns.completion.providers.columns')

  -- Get table reference (could be alias or table name)
  local reference = sql_context.table_ref
  if not reference then
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  -- Try CTE columns first using pre-built context (sync - in memory)
  if context and context.ctes then
    local cte_name = reference
    if context.aliases and context.aliases[reference:lower()] then
      cte_name = context.aliases[reference:lower()]
    end
    local cte_info = context.ctes[cte_name] or context.ctes[cte_name:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(cte_info.columns, connection, context.ctes, cte_info.tables)
      local items = {}
      for _, col_info in ipairs(expanded_columns) do
        local col_name = type(col_info) == "table" and col_info.name or col_info
        if col_name and col_name ~= "*" then
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = "CTE column",
            insertText = col_name,
          })
        end
      end
      vim.schedule(function()
        on_complete(items, nil)
      end)
      return
    end
  end

  -- Try temp table columns (sync - in memory)
  if context and context.temp_tables then
    local temp_name = reference
    if context.aliases and context.aliases[reference:lower()] then
      temp_name = context.aliases[reference:lower()]
    end
    local temp_info = context.temp_tables[temp_name] or context.temp_tables[temp_name:lower()]
    if temp_info and temp_info.columns and #temp_info.columns > 0 then
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(temp_info.columns, connection)
      local items = {}
      for _, col_info in ipairs(expanded_columns) do
        local col_name = type(col_info) == "table" and col_info.name or col_info
        local data_type = type(col_info) == "table" and col_info.data_type or nil
        if col_name and col_name ~= "*" then
          local detail = data_type and ("Temp table column - " .. data_type) or "Temp table column"
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = detail,
            insertText = col_name,
            data = {
              type = "column",
              name = col_name,
              data_type = data_type,
              is_temp_table = true,
            },
          })
        end
      end
      vim.schedule(function()
        on_complete(items, nil)
      end)
      return
    end
  end

  -- Try subquery/derived table columns (sync - in memory)
  if context and context.tables_in_scope then
    for _, table_info in ipairs(context.tables_in_scope) do
      if table_info.is_subquery then
        local sq_name = table_info.name or table_info.alias
        if sq_name and sq_name:lower() == reference:lower() then
          local sq_columns = table_info.columns or {}
          local StatementCache = require('ssns.completion.statement_cache')
          local expanded_columns = StatementCache.expand_star_columns(sq_columns, connection)
          local items = {}
          for _, col_info in ipairs(expanded_columns) do
            local col_name = type(col_info) == "table" and col_info.name or col_info
            if col_name and col_name ~= "*" then
              table.insert(items, {
                label = col_name,
                kind = vim.lsp.protocol.CompletionItemKind.Field,
                detail = "Derived table column",
                insertText = col_name,
              })
            end
          end
          vim.schedule(function()
            on_complete(items, nil)
          end)
          return
        end
      end
    end
  end

  -- Try TVF columns (sync lookup - TVF metadata is cached)
  if context and context.tables_in_scope then
    for _, table_info in ipairs(context.tables_in_scope) do
      if table_info.is_tvf then
        local tvf_alias = table_info.alias or table_info.name
        if tvf_alias and tvf_alias:lower() == reference:lower() then
          local tvf_columns = Resolver.resolve_tvf_columns(
            table_info.function_name or table_info.name,
            table_info.schema,
            connection
          )
          if tvf_columns and #tvf_columns > 0 then
            local items = {}
            for _, col in ipairs(tvf_columns) do
              local col_name = col.name or col.column_name
              local data_type = col.data_type
              local detail = data_type and ("TVF column - " .. data_type) or "TVF column"
              table.insert(items, {
                label = col_name,
                kind = vim.lsp.protocol.CompletionItemKind.Field,
                detail = detail,
                insertText = col_name,
                data = {
                  type = "column",
                  name = col_name,
                  data_type = data_type,
                  is_tvf = true,
                },
              })
            end
            vim.schedule(function()
              on_complete(items, nil)
            end)
            return
          end
        end
      end
    end
  end

  -- Fall back to database table lookup
  local table_obj = nil
  if sql_context.resolved_scope then
    table_obj = Resolver.get_resolved(sql_context.resolved_scope, reference)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(reference, connection, context)
  end

  if not table_obj then
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  -- Get columns async (true non-blocking)
  Resolver.get_columns_async(table_obj, connection, {
    on_complete = function(columns, err)
      if not columns or #columns == 0 then
        on_complete({}, err)
        return
      end

      -- Format as CompletionItems
      local items = {}
      local table_path = ColumnsProvider.resolve_table_path(reference, connection, context, sql_context.resolved_scope)

      for _, col in ipairs(columns) do
        local item = Utils.format_column(col, {
          show_type = true,
          show_nullable = true,
        })

        -- Inject usage weight if we have a table path
        if table_path then
          local col_name = col.name or col.column_name
          if col_name then
            local column_path = string.format("%s.%s", table_path, col_name)
            local weight = BaseProvider.get_usage_weight(connection, "column", column_path)
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

            item.sortText = string.format("%05d_%04d_%s", priority, ordinal, col_name)
            item.data.weight = weight
            item.data.table_path = table_path
          end
        end

        table.insert(items, item)
      end

      on_complete(items, nil)
    end,
  })
end

---Get columns for bracketed qualified reference asynchronously ([schema].[table].|)
---@param sql_context table SQL context { schema: string, table_ref: string, ... }
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@param opts table? Options with on_complete callback
function M.get_qualified_bracket_columns_async(sql_context, connection, context, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')
  local ColumnsProvider = require('ssns.completion.providers.columns')

  -- Build qualified reference from schema and table_ref
  local reference
  if sql_context.schema and sql_context.table_ref then
    reference = string.format("%s.%s", sql_context.schema, sql_context.table_ref)
  elseif sql_context.table_ref then
    reference = sql_context.table_ref
  else
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  -- Try CTE columns first (sync - in memory)
  if context and context.ctes then
    local cte_name = reference
    if context.aliases and context.aliases[reference:lower()] then
      cte_name = context.aliases[reference:lower()]
    end
    local cte_info = context.ctes[cte_name] or context.ctes[cte_name:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      local items = {}
      for _, col_info in ipairs(cte_info.columns) do
        local col_name = type(col_info) == "table" and col_info.name or col_info
        if col_name then
          table.insert(items, {
            label = col_name,
            kind = vim.lsp.protocol.CompletionItemKind.Field,
            detail = "CTE column",
            insertText = col_name,
          })
        end
      end
      vim.schedule(function()
        on_complete(items, nil)
      end)
      return
    end
  end

  -- Fall back to database table lookup
  local table_obj = nil
  if sql_context.resolved_scope then
    table_obj = Resolver.get_resolved(sql_context.resolved_scope, reference)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(reference, connection, context)
  end

  if not table_obj then
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  -- Get columns async (true non-blocking)
  Resolver.get_columns_async(table_obj, connection, {
    on_complete = function(columns, err)
      if not columns or #columns == 0 then
        on_complete({}, err)
        return
      end

      -- Format as CompletionItems
      local items = {}
      local table_path = ColumnsProvider.resolve_table_path(reference, connection, context, sql_context.resolved_scope)

      for _, col in ipairs(columns) do
        local item = Utils.format_column(col, {
          show_type = true,
          show_nullable = true,
        })

        -- Inject usage weight if we have a table path
        if table_path then
          local col_name = col.name or col.column_name
          if col_name then
            local column_path = string.format("%s.%s", table_path, col_name)
            local weight = BaseProvider.get_usage_weight(connection, "column", column_path)
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

            item.sortText = string.format("%05d_%04d_%s", priority, ordinal, col_name)
            item.data.weight = weight
            item.data.table_path = table_path
          end
        end

        table.insert(items, item)
      end

      on_complete(items, nil)
    end,
  })
end

return M
