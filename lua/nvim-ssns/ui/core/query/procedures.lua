---@class QueryProcedures
---Stored procedure parameter support
local QueryProcedures = {}

---Reference to parent UiQuery module (set during init)
---@type UiQuery
local UiQuery

---Check if SQL is a stored procedure execution statement
---@param sql string The SQL to check
---@return boolean is_exec Whether it's an EXEC/EXECUTE statement
---@return string? proc_name The procedure name if found
function QueryProcedures.is_stored_procedure_exec(sql)
  -- Trim whitespace and remove comments
  local trimmed = sql:gsub("^%s+", ""):gsub("%s+$", "")
  trimmed = trimmed:gsub("%-%-[^\n]*\n", "") -- Remove single-line comments
  trimmed = trimmed:gsub("/%*.-%*/", "")    -- Remove multi-line comments
  trimmed = trimmed:gsub("^%s+", "")

  -- Check for EXEC or EXECUTE keyword
  local exec_pattern = "^[Ee][Xx][Ee][Cc]%s+"
  local execute_pattern = "^[Ee][Xx][Ee][Cc][Uu][Tt][Ee]%s+"

  local match_pos = trimmed:match(execute_pattern) or trimmed:match(exec_pattern)
  if not match_pos then
    return false, nil
  end

  -- Extract procedure name (before any parameters or WHERE clause)
  local proc_line = trimmed:match("^[Ee][Xx][Ee][Cc][Uu]?[Tt]?[Ee]?%s+(.+)")
  if not proc_line then
    return false, nil
  end

  -- Get procedure name (stop at space, comma, or semicolon)
  local proc_name = proc_line:match("^([^%s,;@]+)")
  if proc_name then
    -- Remove square brackets if present
    proc_name = proc_name:gsub("%[", ""):gsub("%]", "")
    return true, proc_name
  end

  return false, nil
end

---Parse schema and procedure name
---@param full_name string The full procedure name (e.g., "dbo.MyProc" or "MyProc")
---@return string? schema_name
---@return string proc_name
function QueryProcedures.parse_procedure_name(full_name)
  local parts = vim.split(full_name, ".", { plain = true })
  if #parts == 2 then
    return parts[1], parts[2]
  elseif #parts == 1 then
    return "dbo", parts[1]  -- Default schema for SQL Server
  end
  return nil, full_name
end

---Prompt for procedure parameters and execute
---@param bufnr number Buffer number
---@param sql string Original SQL
---@param server ServerClass Server instance
---@param database_name string? Database name
function QueryProcedures.execute_with_params(bufnr, sql, server, database_name)
  local is_exec, proc_name = QueryProcedures.is_stored_procedure_exec(sql)
  if not is_exec or not proc_name then
    vim.notify("SSNS: Could not parse procedure name from: " .. sql:sub(1, 50), vim.log.levels.ERROR)
    return
  end

  local schema_name, bare_proc_name = QueryProcedures.parse_procedure_name(proc_name)

  -- Get parameters from database
  local adapter = server:get_adapter()
  local params_query = adapter:get_parameters_query(database_name or "master", schema_name, bare_proc_name, "PROCEDURE")

  vim.notify("SSNS: Fetching procedure parameters...", vim.log.levels.INFO)

  local Connection = require('nvim-ssns.connection')
  local params_result = Connection.execute(server.connection_config, params_query)

  if not params_result.success then
    vim.notify("SSNS: Failed to fetch parameters: " .. (params_result.error and params_result.error.message or "Unknown error"),
      vim.log.levels.ERROR)
    return
  end

  local parameters = adapter:parse_parameters(params_result)

  if #parameters == 0 then
    -- No parameters, just execute directly
    UiQuery.execute_query(bufnr, false)
    return
  end

  -- Show parameter input UI
  local UiParamInput = require('nvim-ssns.ui.dialogs.param_input')
  UiParamInput.show_input(
    (schema_name and schema_name .. "." or "") .. bare_proc_name,
    server.name,
    database_name,
    parameters,
    function(values)
      -- Build EXEC statement with parameter values
      local exec_statement = QueryProcedures.build_exec_statement(schema_name, bare_proc_name, parameters, values)

      -- Create temporary buffer with the built statement
      local temp_lines = vim.split(exec_statement, "\n")
      local temp_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, temp_lines)

      -- Execute using the temporary buffer
      local buffer_info = UiQuery.query_buffers[bufnr]
      UiQuery.query_buffers[temp_buf] = buffer_info

      UiQuery.execute_query(temp_buf, false)

      -- Clean up temp buffer
      vim.api.nvim_buf_delete(temp_buf, { force = true })
    end
  )
end

---Build EXEC statement with parameter values
---@param schema_name string? Schema name
---@param proc_name string Procedure name
---@param parameters table[] Parameter definitions
---@param values table<string, string> Parameter values
---@return string exec_statement
function QueryProcedures.build_exec_statement(schema_name, proc_name, parameters, values)
  local full_name = schema_name and string.format("[%s].[%s]", schema_name, proc_name) or string.format("[%s]", proc_name)
  local param_parts = {}

  for _, param in ipairs(parameters) do
    if param.direction == "IN" or param.direction == "INOUT" then
      local value = values[param.name] or ""

      -- Quote string values, keep numbers as-is
      if value == "" or value:lower() == "null" then
        value = "NULL"
      elseif param.data_type:match("char") or param.data_type:match("date") or param.data_type:match("time") then
        value = "'" .. value:gsub("'", "''") .. "'"  -- Escape single quotes
      end

      table.insert(param_parts, string.format("%s = %s", param.name, value))
    end
  end

  local exec_statement = string.format("EXEC %s %s;", full_name, table.concat(param_parts, ", "))
  return exec_statement
end

---Initialize the procedures module with parent reference
---@param parent UiQuery The parent UiQuery module
function QueryProcedures._init(parent)
  UiQuery = parent
end

return QueryProcedures
