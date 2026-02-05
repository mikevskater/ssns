---@class EtlModule
---ETL script module for SSNS
---Provides parsing and execution of .ssns ETL script files
local M = {}

local EtlParser = require("nvim-ssns.etl.parser")
local Directives = require("nvim-ssns.etl.directives")
local EtlContext = require("nvim-ssns.etl.context")
local EtlExecutor = require("nvim-ssns.etl.executor")

-- Lazy load UI module (avoid circular deps)
local EtlResults
local function get_results_ui()
  if not EtlResults then
    EtlResults = require("nvim-ssns.ui.etl_results")
  end
  return EtlResults
end

-- Re-export parser functions
M.parse = EtlParser.parse
M.validate = EtlParser.validate
M.resolve_dependencies = EtlParser.resolve_dependencies
M.get_block = EtlParser.get_block
M.dump = EtlParser.dump

-- Re-export directives module
M.directives = Directives

-- Re-export context class
M.Context = EtlContext

-- Re-export executor class
M.Executor = EtlExecutor

---Create a new execution context
---@param script EtlScript? Parsed script (optional)
---@return EtlContext
function M.create_context(script)
  return EtlContext.new(script)
end

---Create a new executor
---@param script EtlScript Parsed script
---@param opts EtlExecuteOptions? Options
---@return EtlExecutor
function M.create_executor(script, opts)
  return EtlExecutor.new(script, opts)
end

---Execute an ETL script (convenience function)
---@param script EtlScript Parsed script
---@param opts EtlExecuteOptions? Options
---@return EtlExecutionSummary summary
---@return EtlContext context
function M.execute(script, opts)
  return EtlExecutor.run(script, opts)
end

---Execute an ETL script with UI progress display
---@param script EtlScript Parsed script
---@param opts EtlExecuteOptions? Options
---@return EtlExecutionSummary summary
---@return EtlContext context
function M.execute_with_ui(script, opts)
  opts = opts or {}

  -- Generate unique script ID
  local script_id = tostring(os.time()) .. "_" .. math.random(1000, 9999)

  -- Create progress callback
  local ui = get_results_ui()
  local progress_callback = ui.create_progress_callback(script_id, script)

  -- Merge with existing callback if provided
  local original_callback = opts.progress_callback
  opts.progress_callback = function(event)
    progress_callback(event)
    if original_callback then
      original_callback(event)
    end
  end

  -- Execute
  return EtlExecutor.run(script, opts)
end

---Display ETL results (after execution)
---@param script EtlScript
---@param context EtlContext
function M.display_results(script, context)
  local ui = get_results_ui()
  ui.display(script, context)
end

---Parse a file by path
---@param file_path string Path to .ssns file
---@return EtlScript? script Parsed script or nil on error
---@return string? error Error message if failed
function M.parse_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil, string.format("Cannot open file: %s", file_path)
  end

  local content = file:read("*a")
  file:close()

  if not content then
    return nil, string.format("Cannot read file: %s", file_path)
  end

  local script = EtlParser.parse(content, file_path)
  return script, nil
end

---Parse the current buffer
---@param bufnr number? Buffer number (defaults to current)
---@return EtlScript? script Parsed script or nil on error
---@return string? error Error message if failed
function M.parse_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local script = EtlParser.parse(content, file_path ~= "" and file_path or nil)

  return script, nil
end

---Validate a script and return detailed results
---@param script EtlScript
---@return table validation_result {valid: boolean, errors: string[]?, block_count: number, variable_count: number}
function M.validate_script(script)
  local valid, errors = EtlParser.validate(script)

  return {
    valid = valid,
    errors = errors,
    block_count = #script.blocks,
    variable_count = vim.tbl_count(script.variables),
  }
end

---Get summary info about a parsed script
---@param script EtlScript
---@return table summary
function M.get_summary(script)
  local sql_blocks = 0
  local lua_blocks = 0
  local servers = {}
  local databases = {}

  for _, block in ipairs(script.blocks) do
    if block.type == "sql" then
      sql_blocks = sql_blocks + 1
    else
      lua_blocks = lua_blocks + 1
    end

    if block.server and not servers[block.server] then
      servers[block.server] = true
    end
    if block.database and not databases[block.database] then
      databases[block.database] = true
    end
  end

  return {
    total_blocks = #script.blocks,
    sql_blocks = sql_blocks,
    lua_blocks = lua_blocks,
    variables = vim.tbl_count(script.variables),
    servers = vim.tbl_keys(servers),
    databases = vim.tbl_keys(databases),
    has_cross_server = vim.tbl_count(servers) > 1,
  }
end

return M
