---Parameter completion provider
---Provides completions for stored procedure and function parameters
---@class ParametersProvider
local ParametersProvider = {}

local BaseProvider = require('nvim-ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
ParametersProvider.get_completions = BaseProvider.create_safe_wrapper(ParametersProvider, "Parameters", true)

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

  local name_lower = name:lower()

  -- Search procedures using database accessor (handles schema-based vs non-schema servers)
  local procedures = database:get_procedures()
  for _, proc in ipairs(procedures) do
    local proc_name_lower = (proc.name or proc.procedure_name or ""):lower()
    local schema_name = proc.schema or proc.schema_name or ""
    -- Also try schema-qualified name
    local qualified_name_lower = (schema_name .. "." .. proc_name_lower):lower()

    if proc_name_lower == name_lower or qualified_name_lower == name_lower then
      return proc
    end
  end

  -- Search functions using database accessor
  local functions = database:get_functions()
  for _, func in ipairs(functions) do
    local func_name_lower = (func.name or func.function_name or ""):lower()
    local schema_name = func.schema or func.schema_name or ""
    -- Also try schema-qualified name
    local qualified_name_lower = (schema_name .. "." .. func_name_lower):lower()

    if func_name_lower == name_lower or qualified_name_lower == name_lower then
      return func
    end
  end

  return nil
end

---Get parameters from procedure/function
---@param proc_obj table ProcedureClass or FunctionClass
---@return table[] items CompletionItems
function ParametersProvider._get_parameters(proc_obj)
  local Utils = require('nvim-ssns.completion.utils')
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
