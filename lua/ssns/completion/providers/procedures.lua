---Procedure and function completion provider
---Provides completions for stored procedures and functions based on SQL context
---@class ProceduresProvider
local ProceduresProvider = {}

---Get procedure/function completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function ProceduresProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return ProceduresProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify("[SSNS] Procedures provider error: " .. tostring(result), vim.log.levels.ERROR)
      end
      callback({})
    end
  end)
end

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

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Iterate through schema children to find procedure_group
  for _, schema in ipairs(database.children) do
    if schema.object_type == "schema" then
      -- Ensure schema is loaded
      if not schema.is_loaded then
        schema:load()
      end

      -- Find the PROCEDURES group in schema children
      for _, child in ipairs(schema.children) do
        if child.object_type == "procedure_group" then
          -- Iterate through procedures in the group
          for _, proc in ipairs(child.children) do
            -- Format using Utils.format_procedure
            local item = Utils.format_procedure(proc, {
              show_schema = Config.ui and Config.ui.show_schema_prefix,
            })
            table.insert(items, item)
          end
          break -- Found procedures group, move to next schema
        end
      end
    end
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

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Iterate through schema children to find function_group
  for _, schema in ipairs(database.children) do
    if schema.object_type == "schema" then
      -- Ensure schema is loaded
      if not schema.is_loaded then
        schema:load()
      end

      -- Find the FUNCTIONS group in schema children
      for _, child in ipairs(schema.children) do
        if child.object_type == "function_group" then
          -- Iterate through functions, filter for scalar functions
          for _, func in ipairs(child.children) do
            -- Only include scalar functions (not table-valued)
            -- Table-valued functions have types like "TF", "IF", or contain "TABLE"
            if func.function_type and not func:is_table_valued() then
              local item = Utils.format_procedure(func, {
                show_schema = Config.ui and Config.ui.show_schema_prefix,
              })
              table.insert(items, item)
            end
          end
          break -- Found functions group, move to next schema
        end
      end
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

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  -- Iterate through schema children to find function_group
  for _, schema in ipairs(database.children) do
    if schema.object_type == "schema" then
      -- Ensure schema is loaded
      if not schema.is_loaded then
        schema:load()
      end

      -- Find the FUNCTIONS group in schema children
      for _, child in ipairs(schema.children) do
        if child.object_type == "function_group" then
          -- Iterate through functions, filter for table-valued functions
          for _, func in ipairs(child.children) do
            -- Only include table-valued functions
            if func:is_table_valued() then
              local item = Utils.format_procedure(func, {
                show_schema = Config.ui and Config.ui.show_schema_prefix,
              })
              table.insert(items, item)
            end
          end
          break -- Found functions group, move to next schema
        end
      end
    end
  end

  return items
end

return ProceduresProvider
