---Column completion provider for SSNS IntelliSense
---Provides context-aware column completions with alias resolution
---@class ColumnsProvider
local ColumnsProvider = {}

local UsageTracker = require('ssns.completion.usage_tracker')
local Config = require('ssns.config')
local FuzzyMatcher = require('ssns.completion.fuzzy_matcher')
local TypeCompatibility = require('ssns.completion.type_compatibility')

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

  elseif sql_context.mode == "on" then
    -- Pattern: JOIN table ON left.col = | (show columns from other tables with fuzzy matching)
    -- But if user typed table_ref. (e.g., d.), use qualified completion instead
    if sql_context.table_ref then
      return ColumnsProvider._get_qualified_columns(sql_context, connection, sql_context)
    end
    return ColumnsProvider._get_on_clause_columns(connection, sql_context)

  elseif sql_context.mode == "where" then
    -- Pattern: WHERE col = | (show columns with type compatibility warnings)
    return ColumnsProvider._get_where_clause_columns(connection, sql_context)

  elseif sql_context.mode == "select" or
         sql_context.mode == "order_by" or sql_context.mode == "group_by" or
         sql_context.mode == "having" or sql_context.mode == "set" then
    -- Pattern: SELECT | or ORDER BY | or GROUP BY | or HAVING | or UPDATE SET | (show columns from all tables in query)
    return ColumnsProvider._get_all_columns_from_query(connection, sql_context)

  elseif sql_context.mode == "qualified_bracket" then
    -- Pattern: [schema].[table].| or [database].|
    return ColumnsProvider._get_qualified_bracket_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "insert_columns" then
    -- Pattern: INSERT INTO table (| - show columns from target table
    return ColumnsProvider._get_insert_columns(connection, sql_context)

  elseif sql_context.mode == "values" then
    -- Pattern: INSERT INTO table (col1, col2) VALUES (|val1, val2)
    return ColumnsProvider._get_values_completions(connection, sql_context)

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
    -- Reference could be CTE name directly or an alias to a CTE
    local cte_name = reference
    -- If reference is an alias, resolve it to the actual table/CTE name
    if context.aliases and context.aliases[reference:lower()] then
      cte_name = context.aliases[reference:lower()]
    end
    local cte_info = context.ctes[cte_name] or context.ctes[cte_name:lower()]
    if cte_info and cte_info.columns and #cte_info.columns > 0 then
      -- Expand star columns (SELECT * in CTE) to actual columns from source table
      local StatementCache = require('ssns.completion.statement_cache')
      local expanded_columns = StatementCache.expand_star_columns(cte_info.columns, connection)
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

  -- Try subquery/derived table columns from tables_in_scope
  if context and context.tables_in_scope then
    for _, table_info in ipairs(context.tables_in_scope) do
      if table_info.is_subquery then
        local sq_name = table_info.name or table_info.alias
        if sq_name and sq_name:lower() == reference:lower() then
          local sq_columns = table_info.columns or {}
          local items = {}
          for _, col_info in ipairs(sq_columns) do
            local col_name = type(col_info) == "table" and col_info.name or col_info
            if col_name then
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

        -- Store weight and table reference in data
        item.data.weight = weight
        item.data.table_ref = table_path

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

  -- Add scalar functions for unqualified column contexts
  local function_items = ColumnsProvider._get_scalar_functions(connection, context)
  for _, item in ipairs(function_items) do
    table.insert(items, item)
  end

  return items
end

---Get columns for ON clause with fuzzy matching
---Shows fully qualified column names (alias.column) prioritized by name match
---@param connection table Connection context
---@param context table SQL context with left_side info
---@return table[] items CompletionItems
function ColumnsProvider._get_on_clause_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  local items = {}
  local FUZZY_THRESHOLD = 0.85

  -- Get left-side column info
  local left_col_name = context.left_side and context.left_side.column_name
  local left_table_ref = context.left_side and context.left_side.table_ref

  -- Try to resolve left-side column type
  local left_col_type = nil
  if left_table_ref and left_col_name and context.resolved_scope then
    local left_table = Resolver.get_resolved(context.resolved_scope, left_table_ref)
    if left_table then
      local left_cols = Resolver.get_columns(left_table, connection)
      for _, col in ipairs(left_cols or {}) do
        local col_name = col.name or col.column_name
        if col_name and col_name:lower() == left_col_name:lower() then
          left_col_type = col.data_type
          break
        end
      end
    end
  end

  -- Get all tables in the query
  local tables_in_scope = context.tables_in_scope or {}

  for _, table_info in ipairs(tables_in_scope) do
    local alias = table_info.alias
    local table_name = table_info.table or table_info.name
    local display_ref = alias or table_name

    -- Check if this is the left-side table (for deprioritizing same-table suggestions)
    local is_left_table = left_table_ref and display_ref and display_ref:lower() == left_table_ref:lower()

    -- Resolve table to get columns
    local table_obj = nil
    if context.resolved_scope then
      table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
      if not table_obj and alias then
        table_obj = Resolver.get_resolved(context.resolved_scope, alias)
      end
    end
    if not table_obj then
      table_obj = Resolver.resolve_table(table_name or alias, connection, context)
    end

    if not table_obj then
      goto continue_table
    end

    -- Build table path for usage weight lookup
    local schema = table_obj.schema or table_obj.schema_name
    local tbl_name = table_obj.name or table_obj.table_name or table_obj.view_name
    local table_path = nil
    if schema and tbl_name then
      table_path = string.format("%s.%s", schema, tbl_name)
    elseif tbl_name then
      table_path = tbl_name
    end

    -- Get columns for this table
    local columns = Resolver.get_columns(table_obj, connection)
    if not columns then
      goto continue_table
    end

    for _, col in ipairs(columns) do
      local col_name = col.name or col.column_name
      if not col_name then
        goto continue_col
      end

      -- Build qualified name
      local qualified_name = display_ref and (display_ref .. "." .. col_name) or col_name

      -- Calculate fuzzy match score and base priority
      local priority = 5000  -- Default priority
      local match_indicator = ""

      if left_col_name then
        local is_match, score = FuzzyMatcher.match_columns(left_col_name, col_name, FUZZY_THRESHOLD)

        if is_match then
          if score >= 1.0 then
            priority = 100
            match_indicator = " ★"
          elseif score >= 0.95 then
            priority = 200
            match_indicator = string.format(" ~%.0f%%", score * 100)
          elseif score >= 0.85 then
            priority = 300 + math.floor((1 - score) * 1000)
            match_indicator = string.format(" ~%.0f%%", score * 100)
          end
        end
      end

      -- Deprioritize same-table columns (e.g., e.col = e.col) but still show them
      if is_left_table then
        priority = priority + 1000
      end

      -- Apply usage weight adjustment
      local weight = 0
      if table_path then
        local column_path = string.format("%s.%s", table_path, col_name)
        weight = get_usage_weight(connection, "column", column_path)
        -- Adjust priority based on usage (lower number = higher priority)
        if weight > 0 and priority >= 1000 then
          -- For non-fuzzy-matched columns, usage can boost priority
          priority = priority - math.min(weight, 500)
        end
      end

      -- Build detail string
      local type_str = col.data_type or "unknown"
      local detail = type_str .. match_indicator

      -- Check type compatibility
      if left_col_type and col.data_type then
        local type_info = TypeCompatibility.get_info(left_col_type, col.data_type)
        if not type_info.compatible then
          priority = priority + 2000
          detail = detail .. " " .. type_info.icon
        elseif type_info.warning then
          detail = detail .. " " .. type_info.icon
        end
      end

      -- Create completion item
      local item = {
        label = qualified_name,
        kind = vim.lsp.protocol.CompletionItemKind.Field,
        detail = detail,
        insertText = qualified_name,
        sortText = string.format("%05d_%s", priority, qualified_name),
        data = {
          table_ref = display_ref,
          column_name = col_name,
          data_type = col.data_type,
          weight = weight,
          table_path = table_path,
        },
      }

      -- Add documentation with column info
      local doc_parts = {}
      table.insert(doc_parts, string.format("**%s.%s**", display_ref, col_name))
      table.insert(doc_parts, "")
      table.insert(doc_parts, string.format("Type: %s", col.data_type or "unknown"))
      if col.is_nullable ~= nil then
        table.insert(doc_parts, string.format("Nullable: %s", col.is_nullable and "Yes" or "No"))
      end
      if col.is_primary_key or col.is_pk then
        table.insert(doc_parts, "Primary Key: Yes")
      end

      -- Add type warning to docs
      if left_col_type and col.data_type then
        local type_info = TypeCompatibility.get_info(left_col_type, col.data_type)
        if type_info.warning then
          table.insert(doc_parts, "")
          table.insert(doc_parts, type_info.icon .. " " .. type_info.warning)
        end
      end

      item.documentation = {
        kind = "markdown",
        value = table.concat(doc_parts, "\n"),
      }

      table.insert(items, item)

      ::continue_col::
    end

    ::continue_table::
  end

  -- Sort by priority
  table.sort(items, function(a, b)
    return a.sortText < b.sortText
  end)

  return items
end

---Get columns for WHERE clause with type compatibility checking
---Shows type warnings when comparing incompatible column types
---@param connection table Connection context
---@param context table SQL context with left_side info
---@return table[] items CompletionItems
function ColumnsProvider._get_where_clause_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get base columns from all tables in query
  local base_items = ColumnsProvider._get_all_columns_from_query(connection, context)

  -- If no left-side column info, return base items
  if not context.left_side then
    return base_items
  end

  local left_col_name = context.left_side.column_name
  local left_table_ref = context.left_side.table_ref

  -- Try to resolve left-side column type
  local left_col_type = nil
  if left_table_ref and context.resolved_scope then
    local left_table = Resolver.get_resolved(context.resolved_scope, left_table_ref)
    if left_table then
      local left_cols = Resolver.get_columns(left_table, connection)
      for _, col in ipairs(left_cols or {}) do
        local col_name = col.name or col.column_name
        if col_name and col_name:lower() == left_col_name:lower() then
          left_col_type = col.data_type
          break
        end
      end
    end
  end

  -- If we couldn't determine left-side type, return base items
  if not left_col_type then
    return base_items
  end

  -- Enhance items with type compatibility info
  for _, item in ipairs(base_items) do
    local item_type = item.data and item.data.data_type

    if item_type then
      local type_info = TypeCompatibility.get_info(left_col_type, item_type)

      if not type_info.compatible then
        -- Incompatible type - add warning icon and demote priority
        item.detail = (item.detail or "") .. " " .. type_info.icon

        -- Adjust priority (add 2000 to push incompatible to bottom)
        local current_priority = tonumber(item.sortText:match("^(%d+)")) or 5000
        item.sortText = string.format("%05d_%s", current_priority + 2000, item.label)

        -- Add warning to documentation
        local doc = item.documentation
        if type(doc) == "table" and doc.value then
          doc.value = doc.value .. "\n\n" .. type_info.icon .. " " .. type_info.warning
        elseif type(doc) == "string" then
          item.documentation = doc .. "\n\n" .. type_info.icon .. " " .. type_info.warning
        else
          item.documentation = {
            kind = "markdown",
            value = type_info.icon .. " " .. type_info.warning,
          }
        end
      elseif type_info.warning then
        -- Implicit conversion warning (not incompatible, just a note)
        item.detail = (item.detail or "") .. " " .. type_info.icon
      end
    end
  end

  -- Re-sort by updated priorities
  table.sort(base_items, function(a, b)
    return (a.sortText or "") < (b.sortText or "")
  end)

  return base_items
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

---Get completion hints for VALUES clause: INSERT INTO table (col1, col2) VALUES (|
---Shows the column name, type, and nullable info for the current position
---@param connection table Connection context
---@param context table SQL context with value_position and chunk.insert_columns
---@return table[] items CompletionItems
function ColumnsProvider._get_values_completions(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')
  local Utils = require('ssns.completion.utils')

  -- Get INSERT target table and column list
  if not context.chunk or not context.chunk.tables or #context.chunk.tables == 0 then
    return {}
  end

  local insert_columns = context.chunk.insert_columns
  if not insert_columns or #insert_columns == 0 then
    return {}
  end

  -- Get the column at current value position (0-indexed)
  local value_position = context.value_position or 0
  local target_column_name = insert_columns[value_position + 1]  -- Lua is 1-indexed

  if not target_column_name then
    -- Position beyond column list
    return {}
  end

  -- Resolve INSERT target table to get column metadata
  local target_table = context.chunk.tables[1]
  local table_name = target_table.name or target_table

  local table_obj = nil
  if context.resolved_scope then
    table_obj = Resolver.get_resolved(context.resolved_scope, table_name)
  end
  if not table_obj then
    table_obj = Resolver.resolve_table(table_name, connection, context)
  end

  if not table_obj then
    -- Can't resolve table, return column name as basic hint
    return {{
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",  -- Don't insert anything, just show hint
      sortText = "0001_" .. target_column_name,
    }}
  end

  -- Get column metadata
  local columns = Resolver.get_columns(table_obj, connection)
  if not columns or #columns == 0 then
    return {{
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",
      sortText = "0001_" .. target_column_name,
    }}
  end

  -- Find the target column in metadata
  local target_col = nil
  for _, col in ipairs(columns) do
    if col.name:lower() == target_column_name:lower() then
      target_col = col
      break
    end
  end

  local items = {}

  if target_col then
    -- Build detailed column hint
    local type_info = target_col.data_type or "unknown"
    local nullable_info = target_col.is_nullable and "nullable" or "NOT NULL"
    local pk_info = (target_col.is_primary_key or target_col.is_pk) and " [PK]" or ""
    local identity_info = target_col.is_identity and " [IDENTITY]" or ""
    local computed_info = target_col.is_computed and " [COMPUTED]" or ""

    -- Build documentation
    local doc_lines = {
      string.format("**%s** - Column %d of %d", target_column_name, value_position + 1, #insert_columns),
      "",
      string.format("Type: %s", type_info),
      string.format("Nullable: %s", nullable_info),
    }

    if target_col.column_default then
      table.insert(doc_lines, string.format("Default: %s", target_col.column_default))
    end

    if target_col.is_identity then
      table.insert(doc_lines, "")
      table.insert(doc_lines, "⚠️ IDENTITY column - value auto-generated")
    end

    if target_col.is_computed then
      table.insert(doc_lines, "")
      table.insert(doc_lines, "⚠️ COMPUTED column - cannot insert directly")
    end

    -- Primary hint: column name with full details
    table.insert(items, {
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("%s (%s)%s%s%s", type_info, nullable_info, pk_info, identity_info, computed_info),
      documentation = {
        kind = "markdown",
        value = table.concat(doc_lines, "\n"),
      },
      insertText = "",  -- Don't insert column name, user is entering value
      sortText = "0001_" .. target_column_name,
    })

    -- If nullable, suggest NULL
    if target_col.is_nullable then
      table.insert(items, {
        label = "NULL",
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = "NULL value (column is nullable)",
        insertText = "NULL",
        sortText = "0002_NULL",
      })
    end

    -- If has default, suggest DEFAULT
    if target_col.column_default then
      table.insert(items, {
        label = "DEFAULT",
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = string.format("Use default: %s", target_col.column_default),
        insertText = "DEFAULT",
        sortText = "0003_DEFAULT",
      })
    end
  else
    -- Column not found in metadata, return basic hint
    table.insert(items, {
      label = target_column_name,
      kind = vim.lsp.protocol.CompletionItemKind.Field,
      detail = string.format("Column %d of %d", value_position + 1, #insert_columns),
      insertText = "",
      sortText = "0001_" .. target_column_name,
    })
  end

  return items
end

---Get scalar functions for unqualified column contexts (SELECT, WHERE, etc.)
---Scalar functions can be used in expressions alongside columns
---@param connection table Connection context
---@param context table SQL context
---@return table[] items CompletionItems for scalar functions
function ColumnsProvider._get_scalar_functions(connection, context)
  local items = {}

  if not connection or not connection.database then
    return items
  end

  local database = connection.database

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Helper to add functions from a functions_group
  local function add_functions_from_group(functions_group, default_schema)
    if not functions_group or not functions_group.children then
      return
    end

    for _, func_obj in ipairs(functions_group.children) do
      -- Skip table-valued functions - only include scalar functions
      if func_obj.is_table_valued and func_obj:is_table_valued() then
        goto continue_func
      end

      local func_name = func_obj.name or func_obj.function_name
      local schema = func_obj.schema or func_obj.schema_name or default_schema or "dbo"

      if func_name then
        -- Build schema-qualified name (e.g., "dbo.fn_GetEmployeeFullName")
        local qualified_name = schema .. "." .. func_name

        local item = {
          label = qualified_name,
          kind = vim.lsp.protocol.CompletionItemKind.Function,
          detail = "Scalar Function",
          insertText = qualified_name,
          filterText = func_name, -- Allow filtering by just function name
          sortText = string.format("%05d_%s", 6000, func_name), -- After columns
          data = {
            type = "function",
            schema = schema,
            name = func_name,
          },
        }

        -- Add documentation if return type is available
        if func_obj.return_type then
          item.detail = string.format("Scalar Function → %s", func_obj.return_type)
          item.documentation = {
            kind = "markdown",
            value = string.format("**%s**\n\nReturns: `%s`", qualified_name, func_obj.return_type),
          }
        end

        table.insert(items, item)
      end

      ::continue_func::
    end
  end

  -- First, check for top-level functions_group in database
  for _, child in ipairs(database.children or {}) do
    if child.object_type == "functions_group" then
      add_functions_from_group(child, "dbo")
    end
  end

  -- Also iterate through schemas to get functions from all schemas (e.g., hr.fn_*)
  local schemas = database:get_schemas()
  if schemas then
    for _, schema_obj in ipairs(schemas) do
      local schema_name = schema_obj.name or schema_obj.schema_name
      -- Skip system schemas
      if schema_name and not schema_name:match("^sys") and not schema_name:match("^INFORMATION_SCHEMA") then
        -- Check if schema has functions_group
        if schema_obj.children then
          for _, child in ipairs(schema_obj.children) do
            if child.object_type == "functions_group" then
              add_functions_from_group(child, schema_name)
            end
          end
        end
      end
    end
  end

  return items
end

return ColumnsProvider
