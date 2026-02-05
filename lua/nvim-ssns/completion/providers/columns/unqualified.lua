---Unqualified column completion handlers
---Handles SELECT |, WHERE |, ORDER BY |, GROUP BY |, etc. patterns
---@class ColumnsUnqualified
local M = {}

local BaseProvider = require('nvim-ssns.completion.providers.base_provider')
local TypeCompatibility = require('nvim-ssns.completion.type_compatibility')
local Thread = require('nvim-ssns.async.thread')

---Format sorted columns as completion items
---@param sorted_columns table[] Columns from dedupe_sort
---@param connection table Connection context
---@param context table SQL context
---@return table[] items Completion items
local function format_columns_as_items(sorted_columns, connection, context)
  local Utils = require('nvim-ssns.completion.utils')
  local items = {}

  for _, col in ipairs(sorted_columns) do
    local item = Utils.format_column({
      name = col.name,
      column_name = col.name,
      data_type = col.data_type,
      is_nullable = col.is_nullable,
      is_primary_key = col.is_primary_key,
      ordinal_position = col.ordinal_position,
    }, {
      show_type = true,
      show_nullable = true,
    })

    -- Add table name to detail
    if col.table_name then
      local original_detail = item.detail or ""
      item.detail = string.format("%s (%s)", original_detail, col.table_name)
    end

    -- Use sortText
    item.sortText = col.sortText

    -- Store metadata
    item.data.weight = col.computed_weight or col.weight or 0
    item.data.table_ref = col.table_path

    table.insert(items, item)
  end

  -- Add scalar functions
  local function_items = M._get_scalar_functions(connection, context)
  for _, func_item in ipairs(function_items) do
    table.insert(items, func_item)
  end

  return items
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

-- ============================================================================
-- Async Methods
-- ============================================================================

---Get columns from all tables in query asynchronously
---Uses callback aggregation to fetch columns from all tables in parallel
---Then offloads deduplication/sorting to a worker thread
---@param connection table Connection context
---@param context table Pre-built context with tables_in_scope
---@param opts table? Options with on_complete callback
function M.get_all_columns_from_query_async(connection, context, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end
  local cancel_token = opts.cancel_token

  local Resolver = require('nvim-ssns.completion.metadata.resolver')
  local Debug = require('nvim-ssns.debug')

  -- Get all tables from query using pre-built context
  local tables = Resolver.resolve_all_tables_in_query(connection, context)
  if not tables or #tables == 0 then
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  -- Callback aggregation: fetch columns from all tables in parallel
  local pending = #tables
  local all_columns = {}  -- table_index -> columns array
  local table_paths = {}  -- table_index -> table path string
  local has_error = false

  local function check_complete()
    pending = pending - 1
    if pending == 0 and not has_error then
      -- Check cancellation before processing results
      if cancel_token and cancel_token.is_cancelled then
        return
      end

      -- Prepare column data for worker thread
      -- Pre-compute weights on main thread (needs UsageTracker access)
      local worker_columns = {}

      for table_idx, table_obj in ipairs(tables) do
        local columns = all_columns[table_idx] or {}
        local table_path = table_paths[table_idx]
        local table_name = table_obj.name or table_obj.table_name or table_obj.view_name

        for _, col in ipairs(columns) do
          local col_name = col.name or col.column_name
          if col_name then
            -- Pre-compute weight on main thread
            local weight = 0
            if table_path then
              local column_path = string.format("%s.%s", table_path, col_name)
              weight = BaseProvider.get_usage_weight(connection, "column", column_path)
            end

            -- Extract serializable column data for worker
            table.insert(worker_columns, {
              name = col_name,
              data_type = col.data_type,
              is_nullable = col.is_nullable,
              is_primary_key = col.is_primary_key,
              ordinal_position = col.ordinal_position,
              weight = weight,
              table_path = table_path,
              table_name = table_name,
            })
          end
        end
      end

      Debug.log(string.format("[COLUMNS] Processing %d columns for dedupe/sort", #worker_columns))

      -- Offload deduplication and sorting to worker thread
      local task_id, err = Thread.start({
        worker = "dedupe_sort",
        input = { columns = worker_columns },
        on_progress = function(pct, message)
          Debug.log(string.format("[COLUMNS] Thread progress: %d%% - %s", pct, message or ""))
        end,
        on_complete = function(result, thread_err)
          -- Check cancellation
          if cancel_token and cancel_token.is_cancelled then
            return
          end

          if thread_err then
            Debug.log(string.format("[COLUMNS] Thread error: %s", thread_err))
            on_complete({}, thread_err)
            return
          end

          -- Format results as blink.cmp items on main thread
          local sorted_columns = result and result.columns or {}
          local items = format_columns_as_items(sorted_columns, connection, context)

          Debug.log(string.format("[COLUMNS] Thread complete, returning %d items", #items))
          on_complete(items, nil)
        end,
        cancel_token = cancel_token,
        timeout_ms = opts.timeout_ms or 30000,
      })

      if not task_id then
        Debug.log(string.format("[COLUMNS] Failed to start thread: %s", err or "unknown"))
        on_complete({}, err or "Failed to start worker thread")
      end
    end
  end

  -- Fetch columns from all tables in parallel
  for table_idx, table_obj in ipairs(tables) do
    -- Pre-compute table path
    local schema = table_obj.schema or table_obj.schema_name
    local name = table_obj.name or table_obj.table_name or table_obj.view_name
    if schema and name then
      table_paths[table_idx] = string.format("%s.%s", schema, name)
    elseif name then
      table_paths[table_idx] = name
    end

    Resolver.get_columns_async(table_obj, connection, {
      on_complete = function(columns, err)
        if err and not has_error then
          Debug.log(string.format("[COLUMNS] Async column fetch error for table %d: %s", table_idx, err))
        end
        all_columns[table_idx] = columns or {}
        check_complete()
      end,
    })
  end
end

---Get columns for WHERE clause with type compatibility checking (async)
---@param connection table Connection context
---@param context table SQL context with left_side info
---@param opts table? Options with on_complete callback
function M.get_where_clause_columns_async(connection, context, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end
  local cancel_token = opts.cancel_token

  local Resolver = require('nvim-ssns.completion.metadata.resolver')

  -- Get base columns async first
  M.get_all_columns_from_query_async(connection, context, {
    cancel_token = cancel_token,
    on_complete = function(base_items, err)
      -- Check cancellation
      if cancel_token and cancel_token.is_cancelled then
        return
      end

      if err then
        on_complete({}, err)
        return
      end

      -- If no left-side column info, return base items
      if not context.left_side then
        on_complete(base_items, nil)
        return
      end

      local left_col_name = context.left_side.column_name
      local left_table_ref = context.left_side.table_ref

      -- Try to resolve left-side column type
      local left_col_type = nil
      if left_table_ref and context.resolved_scope then
        local left_table = Resolver.get_resolved(context.resolved_scope, left_table_ref)
        if left_table then
          -- Use async to get left table columns
          Resolver.get_columns_async(left_table, connection, {
            on_complete = function(left_cols, _)
              -- Check cancellation
              if cancel_token and cancel_token.is_cancelled then
                return
              end

              for _, col in ipairs(left_cols or {}) do
                local col_name = col.name or col.column_name
                if col_name and col_name:lower() == left_col_name:lower() then
                  left_col_type = col.data_type
                  break
                end
              end

              -- Continue with type compatibility checking
              M._apply_type_compatibility(base_items, left_col_type, on_complete)
            end,
          })
          return
        end
      end

      -- No left-side type found, return base items
      on_complete(base_items, nil)
    end,
  })
end

---Internal helper: apply type compatibility info to items
---@param base_items table[] Items to enhance
---@param left_col_type string? Left-side column type
---@param on_complete function Callback
function M._apply_type_compatibility(base_items, left_col_type, on_complete)
  -- If we couldn't determine left-side type, return base items
  if not left_col_type then
    on_complete(base_items, nil)
    return
  end

  -- Enhance items with type compatibility info
  for _, item in ipairs(base_items) do
    local item_type = item.data and item.data.data_type

    if item_type then
      local type_info = TypeCompatibility.get_info(left_col_type, item_type)

      if not type_info.compatible then
        -- Incompatible type - add warning icon and demote priority
        item.detail = (item.detail or "") .. " " .. type_info.icon

        local current_priority = tonumber(item.sortText:match("^(%d+)")) or 5000
        item.sortText = string.format("%05d_%s", current_priority + 2000, item.label)

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
        item.detail = (item.detail or "") .. " " .. type_info.icon
      end
    end
  end

  -- Re-sort by updated priorities
  table.sort(base_items, function(a, b)
    return (a.sortText or "") < (b.sortText or "")
  end)

  on_complete(base_items, nil)
end

return M
