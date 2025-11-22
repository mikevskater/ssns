---Parameter completion provider
---Provides completions for stored procedure and function parameters
---@class ParametersProvider
local ParametersProvider = {}

---Get parameter completions for the given context
---@param ctx table Context from source (has bufnr, connection, sql_context)
---@param callback function Callback(items)
function ParametersProvider.get_completions(ctx, callback)
  -- Wrap in pcall for error handling
  local success, result = pcall(function()
    return ParametersProvider._get_completions_impl(ctx)
  end)

  -- Schedule callback with results or empty array on error
  vim.schedule(function()
    if success then
      callback(result or {})
    else
      if vim.g.ssns_debug then
        vim.notify("[SSNS] Parameters provider error: " .. tostring(result), vim.log.levels.ERROR)
      end
      callback({})
    end
  end)
end

---Internal implementation of parameter completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function ParametersProvider._get_completions_impl(ctx)
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Get procedure/function name from context
  local proc_name = sql_context.procedure or sql_context.function_name
  if not proc_name then
    return {}
  end

  -- Find procedure or function
  local proc_obj = ParametersProvider._find_procedure_or_function(proc_name, connection)
  if not proc_obj then
    return {}
  end

  -- Get parameters
  return ParametersProvider._get_parameters(proc_obj)
end

---Find procedure or function by name
---@param name string Procedure/function name
---@param connection table Connection context
---@return table? proc_obj ProcedureClass or FunctionClass or nil
function ParametersProvider._find_procedure_or_function(name, connection)
  local database = connection.database
  if not database then
    return nil
  end

  -- Ensure database is loaded
  if not database.is_loaded then
    database:load()
  end

  local name_lower = name:lower()

  -- Search through all schemas
  for _, schema in ipairs(database.children) do
    if schema.object_type == "schema" then
      -- Ensure schema is loaded
      if not schema.is_loaded then
        schema:load()
      end

      -- Search in procedure_group
      for _, child in ipairs(schema.children) do
        if child.object_type == "procedure_group" then
          for _, proc in ipairs(child.children) do
            local proc_name_lower = (proc.name or proc.procedure_name or ""):lower()
            -- Also try schema-qualified name
            local qualified_name_lower = (proc.schema_name .. "." .. proc_name_lower):lower()

            if proc_name_lower == name_lower or qualified_name_lower == name_lower then
              return proc
            end
          end
        end
      end

      -- Search in function_group
      for _, child in ipairs(schema.children) do
        if child.object_type == "function_group" then
          for _, func in ipairs(child.children) do
            local func_name_lower = (func.name or func.function_name or ""):lower()
            -- Also try schema-qualified name
            local qualified_name_lower = (func.schema_name .. "." .. func_name_lower):lower()

            if func_name_lower == name_lower or qualified_name_lower == name_lower then
              return func
            end
          end
        end
      end
    end
  end

  return nil
end

---Get parameters from procedure/function
---@param proc_obj table ProcedureClass or FunctionClass
---@return table[] items CompletionItems
function ParametersProvider._get_parameters(proc_obj)
  local Utils = require('ssns.completion.utils')
  local items = {}

  -- Get parameters (may be lazy-loaded)
  local params = proc_obj:get_parameters()

  if not params or #params == 0 then
    return items
  end

  -- Format each parameter
  for _, param in ipairs(params) do
    local item = Utils.format_parameter(param, {})
    table.insert(items, item)
  end

  return items
end

return ParametersProvider
