---Unqualified column completion handlers
---Handles SELECT |, WHERE |, ORDER BY |, GROUP BY |, etc. patterns
---@class ColumnsUnqualified
local M = {}

local BaseProvider = require('ssns.completion.providers.base_provider')
local TypeCompatibility = require('ssns.completion.type_compatibility')

---Get columns from all tables in query (for SELECT, WHERE, ORDER BY, GROUP BY)
---@param connection table Connection context
---@param context table Pre-built context with tables_in_scope
---@return table[] items CompletionItems
function M.get_all_columns_from_query(connection, context)
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
          weight = BaseProvider.get_usage_weight(connection, "column", column_path)
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
  local function_items = M._get_scalar_functions(connection, context)
  for _, item in ipairs(function_items) do
    table.insert(items, item)
  end

  return items
end

---Get columns for WHERE clause with type compatibility checking
---Shows type warnings when comparing incompatible column types
---@param connection table Connection context
---@param context table SQL context with left_side info
---@return table[] items CompletionItems
function M.get_where_clause_columns(connection, context)
  local Resolver = require('ssns.completion.metadata.resolver')

  -- Get base columns from all tables in query
  local base_items = M.get_all_columns_from_query(connection, context)

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

---Get scalar functions for unqualified column contexts (SELECT, WHERE, etc.)
---Scalar functions can be used in expressions alongside columns
---@param connection table Connection context
---@param context table SQL context
---@return table[] items CompletionItems for scalar functions
function M._get_scalar_functions(connection, context)
  local items = {}

  if not connection or not connection.database then
    return items
  end

  local database = connection.database

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local functions = database:get_functions()

  for _, func_obj in ipairs(functions) do
    -- Skip table-valued functions - only include scalar functions
    if func_obj.is_table_valued and func_obj:is_table_valued() then
      goto continue_func
    end

    local func_name = func_obj.name or func_obj.function_name
    local schema = func_obj.schema or func_obj.schema_name or "dbo"

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

  return items
end

return M
