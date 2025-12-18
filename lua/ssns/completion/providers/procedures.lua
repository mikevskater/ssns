---Procedure and function completion provider
---Provides completions for stored procedures and functions based on SQL context
---@class ProceduresProvider
local ProceduresProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
ProceduresProvider.get_completions = BaseProvider.create_safe_wrapper(ProceduresProvider, "Procedures", true)

---Internal implementation of procedure/function completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ProceduresProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Route based on context mode
  if sql_context.mode == "exec" then
    -- EXEC | context → show procedures
    return ProceduresProvider._get_procedures(connection)

  elseif sql_context.mode == "select_function" then
    -- SELECT dbo.| context → show scalar functions
    return ProceduresProvider._get_scalar_functions(connection)

  elseif sql_context.mode == "from_function" then
    -- FROM dbo.| context → show table-valued functions
    return ProceduresProvider._get_table_functions(connection)

  else
    -- Show both procedures and functions by default
    local items = {}
    local procs = ProceduresProvider._get_procedures(connection)
    local funcs_scalar = ProceduresProvider._get_scalar_functions(connection)
    local funcs_table = ProceduresProvider._get_table_functions(connection)

    vim.list_extend(items, procs)
    vim.list_extend(items, funcs_scalar)
    vim.list_extend(items, funcs_table)

    return items
  end
end

---Get stored procedures
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_procedures(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local procedures = database:get_procedures()

  for idx, proc_obj in ipairs(procedures) do
    local item = Utils.format_procedure(proc_obj, {
      show_schema = Config.ui and Config.ui.show_schema_prefix,
      priority = 1,
      with_params = true,
    })

    -- Get procedure name and schema for weight lookup
    local proc_name = proc_obj.name or proc_obj.procedure_name
    local schema = proc_obj.schema or proc_obj.schema_name

    if proc_name and schema then
      -- Build procedure path: schema.procedure
      local proc_path = string.format("%s.%s", schema, proc_name)

      -- Apply usage weight using BaseProvider
      BaseProvider.apply_usage_weight(item, connection, "procedure", proc_path, idx)
    end

    table.insert(items, item)
  end

  return items
end

---Get scalar functions
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_scalar_functions(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local functions = database:get_functions()

  for idx, func_obj in ipairs(functions) do
    -- Only include scalar functions
    if func_obj.function_type == "SCALAR" then
      local item = Utils.format_procedure(func_obj, {
        show_schema = Config.ui and Config.ui.show_schema_prefix,
        priority = 2,
        with_params = true,
      })

      -- Get function name and schema for weight lookup
      local func_name = func_obj.name or func_obj.function_name
      local schema = func_obj.schema or func_obj.schema_name

      if func_name and schema then
        -- Build function path: schema.function
        local func_path = string.format("%s.%s", schema, func_name)

        -- Apply usage weight using BaseProvider
        BaseProvider.apply_usage_weight(item, connection, "function", func_path, idx)
      end

      table.insert(items, item)
    end
  end

  return items
end

---Get table-valued functions
---@param connection table Connection context
---@return table[] items CompletionItems
function ProceduresProvider._get_table_functions(connection)
  local Utils = require('ssns.completion.utils')
  local Config = require('ssns.config').get()
  local items = {}

  local database = connection.database
  if not database then
    return items
  end

  -- Use database accessor method (handles schema-based vs non-schema servers)
  local functions = database:get_functions()

  for idx, func_obj in ipairs(functions) do
    -- Only include table-valued functions
    if func_obj.function_type == "TABLE" or func_obj.function_type == "INLINE_TABLE" then
      local item = Utils.format_procedure(func_obj, {
        show_schema = Config.ui and Config.ui.show_schema_prefix,
        priority = 2,
        with_params = true,
      })

      -- Get function name and schema for weight lookup
      local func_name = func_obj.name or func_obj.function_name
      local schema = func_obj.schema or func_obj.schema_name

      if func_name and schema then
        -- Build function path: schema.function
        local func_path = string.format("%s.%s", schema, func_name)

        -- Apply usage weight using BaseProvider
        BaseProvider.apply_usage_weight(item, connection, "function", func_path, idx)
      end

      table.insert(items, item)
    end
  end

  return items
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class ProceduresProviderAsyncOpts
---@field on_complete fun(items: table[], error: string?)? Completion callback
---@field timeout_ms number? Timeout in milliseconds (default: 5000)

---Get procedure/function completions asynchronously
---Loads database async before collecting items
---@param ctx table Context { bufnr, connection, sql_context }
---@param opts ProceduresProviderAsyncOpts? Options with on_complete callback
function ProceduresProvider.get_completions_async(ctx, opts)
  opts = opts or {}
  local on_complete = opts.on_complete or function() end

  local connection = ctx.connection
  if not connection or not connection.database then
    vim.schedule(function()
      on_complete({}, nil)
    end)
    return
  end

  local database = connection.database

  -- Load database async if needed
  if not database.is_loaded then
    database:load_async({
      timeout_ms = opts.timeout_ms or 5000,
      on_complete = function(success, err)
        if not success then
          on_complete({}, err)
          return
        end
        -- Run sync impl after load
        vim.schedule(function()
          local ok, result = pcall(function()
            return ProceduresProvider._get_completions_impl(ctx)
          end)
          if ok then
            on_complete(result or {}, nil)
          else
            on_complete({}, tostring(result))
          end
        end)
      end,
    })
    return
  end

  -- Database loaded, run sync impl
  vim.schedule(function()
    local success, result = pcall(function()
      return ProceduresProvider._get_completions_impl(ctx)
    end)
    if success then
      on_complete(result or {}, nil)
    else
      on_complete({}, tostring(result))
    end
  end)
end

return ProceduresProvider
