---Column completion provider for SSNS IntelliSense
---Provides context-aware column completions with alias resolution
---Entry point that routes to specialized handlers
---@class ColumnsProvider
local ColumnsProvider = {}

local BaseProvider = require('nvim-ssns.completion.providers.base_provider')

-- Lazy-loaded submodules
local qualified = nil
local unqualified = nil
local special = nil

---Get the qualified columns submodule
---@return table
local function get_qualified()
  if not qualified then
    qualified = require('nvim-ssns.completion.providers.columns.qualified')
  end
  return qualified
end

---Get the unqualified columns submodule
---@return table
local function get_unqualified()
  if not unqualified then
    unqualified = require('nvim-ssns.completion.providers.columns.unqualified')
  end
  return unqualified
end

---Get the special columns submodule
---@return table
local function get_special()
  if not special then
    special = require('nvim-ssns.completion.providers.columns.special')
  end
  return special
end

-- Use BaseProvider.create_safe_wrapper for standardized error handling
ColumnsProvider.get_completions = BaseProvider.create_safe_wrapper(ColumnsProvider, "Columns", false)

---Resolve table reference to full path for weight lookup
---@param table_ref string Table reference (could be alias, name, etc.)
---@param connection table Connection context
---@param context table Pre-built context with aliases
---@param resolved_scope table? Pre-resolved scope from source
---@return string? path Full path (e.g., "dbo.Employees") or nil
function ColumnsProvider.resolve_table_path(table_ref, connection, context, resolved_scope)
  if not table_ref then
    return nil
  end

  -- Try to resolve via Resolver
  local success, result = pcall(function()
    local Resolver = require('nvim-ssns.completion.metadata.resolver')

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

---Internal implementation of column completion
---Routes to appropriate handler based on context mode
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ColumnsProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Route based on context mode
  -- Note: "qualified" modes can work without connection for CTE/subquery columns
  -- Other modes require database connection for column lookups
  if sql_context.mode == "qualified" or
     sql_context.mode == "select_qualified" or
     sql_context.mode == "where_qualified" then
    -- Pattern: table.| or alias.|
    -- Can work without connection for CTE/subquery columns
    local Debug = require('nvim-ssns.debug')
    Debug.log(string.format("[COLUMNS] Routing mode '%s' to _get_qualified_columns", sql_context.mode or "nil"))
    return get_qualified().get_qualified_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "on" then
    -- Pattern: JOIN table ON left.col = | (show columns from other tables with fuzzy matching)
    -- But if user typed table_ref. (e.g., d.), use qualified completion instead
    if sql_context.table_ref then
      return get_qualified().get_qualified_columns(sql_context, connection, sql_context)
    end
    -- ON clause without table_ref needs database connection
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_on_clause_columns(connection, sql_context)

  elseif sql_context.mode == "where" or
         sql_context.mode == "select" or
         sql_context.mode == "order_by" or sql_context.mode == "group_by" or
         sql_context.mode == "having" or sql_context.mode == "set" then
    -- These modes use async path with threading - see get_completions_async
    -- Return empty from sync path to enforce async usage
    return {}

  elseif sql_context.mode == "qualified_bracket" then
    -- Pattern: [schema].[table].| or [database].|
    -- Can work without connection for CTE columns
    return get_qualified().get_qualified_bracket_columns(sql_context, connection, sql_context)

  elseif sql_context.mode == "insert_columns" then
    -- Pattern: INSERT INTO table (| - show columns from target table
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_insert_columns(connection, sql_context)

  elseif sql_context.mode == "merge_insert_columns" then
    -- Pattern: MERGE ... WHEN NOT MATCHED THEN INSERT (| - show columns from MERGE target table
    -- MERGE target table is also chunk.tables[1], same as regular INSERT
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_insert_columns(connection, sql_context)

  elseif sql_context.mode == "values" then
    -- Pattern: INSERT INTO table (col1, col2) VALUES (|val1, val2)
    if not connection or not connection.database then
      return {}
    end
    return get_special().get_values_completions(connection, sql_context)

  elseif sql_context.mode == "output" then
    -- Pattern: OUTPUT inserted.| or OUTPUT deleted.| (show columns from DML target table)
    if sql_context.table_ref and (sql_context.table_ref:lower() == "inserted" or sql_context.table_ref:lower() == "deleted") then
      -- Get columns from the DML target table
      return get_special().get_output_pseudo_table_columns(connection, sql_context)
    else
      -- "OUTPUT |" uses async path with threading - see get_completions_async
      return {}
    end

  else
    return {}
  end
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class ColumnsProviderAsyncOpts
---@field on_complete fun(items: table[], error: string?)? Completion callback
---@field timeout_ms number? Timeout in milliseconds (default: 5000)

---Get column completions asynchronously
---Pre-resolves scope async, then runs sync implementation
---@param ctx table Context { bufnr, connection, sql_context }
---@param opts ColumnsProviderAsyncOpts? Options with on_complete callback
function ColumnsProvider.get_completions_async(ctx, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end
  local cancel_token = opts.cancel_token

  local connection = ctx.connection
  local sql_context = ctx.sql_context or {}

  -- For modes that don't need database (CTE columns, etc.), run sync immediately
  if not connection or not connection.database then
    -- Some modes can work without database (qualified CTE/subquery columns)
    if sql_context.mode == "qualified" or
       sql_context.mode == "select_qualified" or
       sql_context.mode == "where_qualified" or
       sql_context.mode == "qualified_bracket" then
      vim.schedule(function()
        -- Check cancellation
        if cancel_token and cancel_token.is_cancelled then
          return
        end
        local success, result = pcall(function()
          return ColumnsProvider._get_completions_impl(ctx)
        end)
        if success then
          on_complete(result or {}, nil)
        else
          on_complete({}, tostring(result))
        end
      end)
      return
    end
    -- Other modes need database
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  local database = connection.database

  -- Load database async if needed (use true async RPC)
  if not database.is_loaded then
    database:load_async({
      timeout_ms = opts.timeout_ms or 5000,
      on_complete = function(success, err)
        -- Check cancellation after load
        if cancel_token and cancel_token.is_cancelled then
          return
        end
        if not success then
          on_complete({}, err)
          return
        end
        -- Now pre-resolve scope and run impl
        ColumnsProvider._async_with_resolved_scope(ctx, opts, on_complete)
      end,
    })
    return
  end

  -- Database already loaded, pre-resolve scope
  ColumnsProvider._async_with_resolved_scope(ctx, opts, on_complete)
end

---Internal helper: pre-resolve scope then run async impl for qualified modes
---@param ctx table Context
---@param opts table Options
---@param on_complete function Callback
function ColumnsProvider._async_with_resolved_scope(ctx, opts, on_complete)
  local connection = ctx.connection
  local sql_context = ctx.sql_context or {}
  local Resolver = require('nvim-ssns.completion.metadata.resolver')
  local cancel_token = opts.cancel_token

  -- Check if we need to pre-resolve scope (for column completion)
  local has_tables_to_resolve = sql_context.tables_in_scope and #sql_context.tables_in_scope > 0

  -- Helper to run the completion after pre-resolution
  local function run_completion()
    -- Check cancellation before running
    if cancel_token and cancel_token.is_cancelled then
      return
    end

    -- Route to async methods based on mode to avoid blocking on Resolver.get_columns
    local mode = sql_context.mode
    if mode == "qualified" or mode == "select_qualified" or mode == "where_qualified" then
      -- Use async qualified column resolution
      get_qualified().get_qualified_columns_async(sql_context, connection, sql_context, {
        cancel_token = cancel_token,
        on_complete = on_complete,
      })
    elseif mode == "qualified_bracket" then
      -- Use async bracketed qualified column resolution
      get_qualified().get_qualified_bracket_columns_async(sql_context, connection, sql_context, {
        cancel_token = cancel_token,
        on_complete = on_complete,
      })
    elseif mode == "select" or mode == "order_by" or mode == "group_by" or
           mode == "having" or mode == "set" then
      -- Use async unqualified column resolution (fetches columns from all tables in parallel)
      get_unqualified().get_all_columns_from_query_async(connection, sql_context, {
        cancel_token = cancel_token,
        on_complete = on_complete,
      })
    elseif mode == "where" then
      -- Use async WHERE clause column resolution (with type compatibility)
      get_unqualified().get_where_clause_columns_async(connection, sql_context, {
        cancel_token = cancel_token,
        on_complete = on_complete,
      })
    elseif mode == "on" then
      -- ON clause: show columns from all tables with fuzzy matching
      -- If table_ref is specified (e.g., r.|), use qualified completion
      if sql_context.table_ref then
        get_qualified().get_qualified_columns_async(sql_context, connection, sql_context, {
          cancel_token = cancel_token,
          on_complete = on_complete,
        })
      else
        -- ON | - show columns with fuzzy matching to left side
        vim.schedule(function()
          if cancel_token and cancel_token.is_cancelled then
            return
          end
          local success, result = pcall(function()
            return get_special().get_on_clause_columns(connection, sql_context)
          end)
          on_complete(success and result or {}, not success and tostring(result) or nil)
        end)
      end
    elseif mode == "output" then
      -- OUTPUT mode: if no table_ref or not inserted/deleted, use async columns
      local table_ref = sql_context.table_ref
      if table_ref and (table_ref:lower() == "inserted" or table_ref:lower() == "deleted") then
        -- OUTPUT inserted.| or OUTPUT deleted.| - use sync special handler
        vim.schedule(function()
          if cancel_token and cancel_token.is_cancelled then
            return
          end
          local success, result = pcall(function()
            return get_special().get_output_pseudo_table_columns(connection, sql_context)
          end)
          on_complete(success and result or {}, not success and tostring(result) or nil)
        end)
      else
        -- OUTPUT | - show all columns from query (async with threading)
        get_unqualified().get_all_columns_from_query_async(connection, sql_context, {
          cancel_token = cancel_token,
          on_complete = on_complete,
        })
      end
    else
      -- Other modes: run sync impl (special cases like INSERT, VALUES)
      vim.schedule(function()
        -- Check cancellation before running sync impl
        if cancel_token and cancel_token.is_cancelled then
          return
        end
        local success, result = pcall(function()
          return ColumnsProvider._get_completions_impl(ctx)
        end)
        if success then
          on_complete(result or {}, nil)
        else
          on_complete({}, tostring(result))
        end
      end)
    end
  end

  if has_tables_to_resolve and not sql_context.resolved_scope then
    -- Pre-resolve scope async for better performance
    Resolver.pre_resolve_scope_async(sql_context, connection, {
      timeout_ms = opts.timeout_ms or 5000,
      cancel_token = cancel_token,
      on_complete = function(resolved_scope, err)
        -- Check cancellation after pre-resolution
        if cancel_token and cancel_token.is_cancelled then
          return
        end
        -- Inject resolved scope into context
        sql_context.resolved_scope = resolved_scope
        run_completion()
      end,
    })
  else
    -- No tables to resolve or already resolved
    run_completion()
  end
end

return ColumnsProvider
