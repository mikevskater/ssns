---@class EtlCommands
---Commands for ETL script execution
local M = {}

local EtlParser = require("nvim-ssns.etl.parser")
local EtlExecutor = require("nvim-ssns.etl.executor")
local Config = require("nvim-ssns.config")
local Macros = require("nvim-ssns.etl.macros")
local ContentBuilder = require("nvim-float.content")

-- Lazy load UI module
local EtlResults
local function get_results_ui()
  if not EtlResults then
    EtlResults = require("nvim-ssns.ui.etl_results")
  end
  return EtlResults
end

-- Track active executor for cancellation
---@type EtlExecutor?
local active_executor = nil

---Parse current buffer as ETL script
---@param bufnr number? Buffer number (defaults to current)
---@return EtlScript? script, string? error
local function parse_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local script = EtlParser.parse(content, file_path ~= "" and file_path or nil)

  -- Validate
  local valid, errors = EtlParser.validate(script)
  if not valid then
    return nil, "Validation errors:\n" .. table.concat(errors, "\n")
  end

  return script, nil
end

---Execute ETL script in current buffer
---@param opts table? Options {dry_run: boolean?, block_name: string?}
function M.execute(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()

  -- Parse script
  local script, err = parse_buffer(bufnr)
  if not script then
    vim.notify("ETL Parse Error: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  if #script.blocks == 0 then
    vim.notify("No ETL blocks found in buffer", vim.log.levels.WARN)
    return
  end

  -- Dry run mode
  if opts.dry_run then
    M.show_execution_plan(script)
    return
  end

  -- Get ETL config
  local etl_config = Config.get().etl or {}

  -- Generate unique script ID for progress tracking
  local script_id = tostring(os.time()) .. "_" .. math.random(1000, 9999)

  -- Create progress callback
  local ui = get_results_ui()
  local progress_callback = ui.create_progress_callback(script_id, script)

  -- Notify start
  vim.notify(string.format("Executing ETL script: %d blocks", #script.blocks), vim.log.levels.INFO)

  -- Execute with progress callback
  local executor = EtlExecutor.new(script, {
    progress_callback = progress_callback,
    bufnr = bufnr,
    record_history = etl_config.record_history ~= false,
  })

  -- Track for cancellation
  active_executor = executor

  -- Execute (this is synchronous for now, could be made async)
  local summary = executor:execute()

  -- Clear active executor
  active_executor = nil

  -- Display final results
  local context = executor:get_context()
  ui.display(script, context, script_id)

  -- Notify completion
  if summary.success then
    vim.notify(string.format("ETL complete: %d/%d blocks successful (%dms)",
      summary.blocks_completed, summary.blocks_total, summary.total_time_ms), vim.log.levels.INFO)
  else
    vim.notify(string.format("ETL failed: %s", summary.error or "Unknown error"), vim.log.levels.ERROR)
  end
end

---Execute single block under cursor
function M.execute_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Parse script
  local script, err = parse_buffer(bufnr)
  if not script then
    vim.notify("ETL Parse Error: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Find block at cursor
  local target_block = nil
  for _, block in ipairs(script.blocks) do
    if cursor_line >= block.start_line and cursor_line <= block.end_line then
      target_block = block
      break
    end
  end

  if not target_block then
    vim.notify("No ETL block found at cursor position", vim.log.levels.WARN)
    return
  end

  -- Create a script with just this block (and any dependencies)
  local single_block_script = {
    blocks = { target_block },
    variables = script.variables,
    metadata = script.metadata,
    source_file = script.source_file,
  }

  -- Get ETL config
  local etl_config = Config.get().etl or {}

  -- Generate unique script ID
  local script_id = tostring(os.time()) .. "_block_" .. target_block.name

  -- Create progress callback
  local ui = get_results_ui()
  local progress_callback = ui.create_progress_callback(script_id, single_block_script)

  vim.notify(string.format("Executing block: %s", target_block.name), vim.log.levels.INFO)

  -- Execute
  local executor = EtlExecutor.new(single_block_script, {
    progress_callback = progress_callback,
    bufnr = bufnr,
    record_history = etl_config.record_history ~= false,
  })

  active_executor = executor
  local summary = executor:execute()
  active_executor = nil

  -- Display results
  local context = executor:get_context()
  ui.display(single_block_script, context, script_id)

  if summary.success then
    vim.notify(string.format("Block '%s' complete (%dms)",
      target_block.name, summary.total_time_ms), vim.log.levels.INFO)
  else
    vim.notify(string.format("Block '%s' failed: %s",
      target_block.name, summary.error or "Unknown error"), vim.log.levels.ERROR)
  end
end

---Validate ETL script without executing
function M.validate()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Parse script
  local script, err = parse_buffer(bufnr)
  if not script then
    vim.notify("ETL Validation Failed:\n" .. (err or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Resolve dependencies
  local resolved, dep_errors = EtlParser.resolve_dependencies(script)
  if not resolved then
    vim.notify("ETL Dependency Errors:\n" .. table.concat(dep_errors, "\n"), vim.log.levels.ERROR)
    return
  end

  -- Success
  local servers = {}
  local databases = {}
  for _, block in ipairs(script.blocks) do
    if block.server and not servers[block.server] then
      servers[block.server] = true
    end
    if block.database and not databases[block.database] then
      databases[block.database] = true
    end
  end

  local server_list = vim.tbl_keys(servers)
  local database_list = vim.tbl_keys(databases)

  local msg = string.format(
    "ETL Script Valid:\n" ..
    "  Blocks: %d (%d SQL, %d Lua)\n" ..
    "  Variables: %d\n" ..
    "  Servers: %s\n" ..
    "  Databases: %s",
    #script.blocks,
    vim.tbl_count(vim.tbl_filter(function(b) return b.type == "sql" end, script.blocks)),
    vim.tbl_count(vim.tbl_filter(function(b) return b.type == "lua" end, script.blocks)),
    vim.tbl_count(script.variables),
    #server_list > 0 and table.concat(server_list, ", ") or "none specified",
    #database_list > 0 and table.concat(database_list, ", ") or "none specified"
  )

  vim.notify(msg, vim.log.levels.INFO)
end

---Show execution plan without running (dry run)
---@param script EtlScript? Pre-parsed script (optional)
function M.show_execution_plan(script)
  if not script then
    local err
    script, err = parse_buffer()
    if not script then
      vim.notify("ETL Parse Error: " .. (err or "Unknown error"), vim.log.levels.ERROR)
      return
    end
  end

  local cb = ContentBuilder.new()

  -- Header
  cb:header("ETL Execution Plan")
  cb:separator("─", 60)
  cb:blank()

  -- Variables
  if vim.tbl_count(script.variables) > 0 then
    cb:section("Variables")
    for name, value in pairs(script.variables) do
      cb:spans({
        { text = "  " },
        { text = name, style = "identifier" },
        { text = " = ", style = "muted" },
        { text = vim.inspect(value), style = "string" },
      })
    end
    cb:blank()
  end

  -- Blocks
  cb:section("Execution Order")
  for i, block in ipairs(script.blocks) do
    local type_style = block.type == "sql" and "keyword" or "function"

    -- Build spans for block line
    local spans = {
      { text = string.format("  %d. ", i), style = "number" },
      { text = "[" .. block.type:upper() .. "]", style = type_style },
      { text = " " },
      { text = block.name, style = "identifier" },
    }

    -- Location
    if block.server or block.database then
      local parts = {}
      if block.server then table.insert(parts, block.server) end
      if block.database then table.insert(parts, block.database) end
      table.insert(spans, { text = " → ", style = "muted" })
      table.insert(spans, { text = table.concat(parts, "."), style = "info" })
    end

    -- Dependencies
    if block.input then
      table.insert(spans, { text = " (depends: ", style = "muted" })
      table.insert(spans, { text = block.input, style = "warning" })
      table.insert(spans, { text = ")", style = "muted" })
    end

    cb:spans(spans)

    -- Description on second line
    if block.description then
      cb:styled("     " .. block.description, "muted")
    end
  end

  -- Summary
  cb:blank()
  cb:separator("─", 60)

  local servers = {}
  for _, block in ipairs(script.blocks) do
    if block.server then
      servers[block.server] = true
    end
  end

  cb:spans({
    { text = "Total: " },
    { text = tostring(#script.blocks), style = "number" },
    { text = " blocks | Servers: " },
    { text = vim.tbl_count(servers) > 0 and table.concat(vim.tbl_keys(servers), ", ") or "none", style = "info" },
  })

  -- Display in a floating window
  local Float = require('nvim-float.window')
  local win = Float.create_styled(cb, {
    title = "ETL Dry Run",
    min_width = 70,
    max_height = 30,
    center = true,
    focusable = true,
    footer = "q: close",
  })

  if win then
    vim.keymap.set("n", "q", function() win:close() end, { buffer = win.buf, nowait = true })
    vim.keymap.set("n", "<Esc>", function() win:close() end, { buffer = win.buf, nowait = true })
  end
end

---Cancel running ETL execution
function M.cancel()
  if active_executor then
    active_executor:cancel()
    vim.notify("ETL execution cancelled", vim.log.levels.WARN)
  else
    vim.notify("No ETL execution is running", vim.log.levels.INFO)
  end
end

---Reload all macros
function M.macros_reload()
  local success = Macros.reload(true)
  local stats = Macros.get_stats()

  if success then
    vim.notify(string.format("Macros reloaded: %d macros from %d files",
      stats.macro_count, stats.file_count), vim.log.levels.INFO)
  else
    local errors = Macros.get_errors()
    local msg = string.format("Macros reloaded with errors: %d macros, %d errors",
      stats.macro_count, stats.error_count)
    for _, err in ipairs(errors) do
      msg = msg .. "\n  " .. err.file .. ": " .. err.error
    end
    vim.notify(msg, vim.log.levels.WARN)
  end
end

---List all loaded macros
function M.macros_list()
  local info = Macros.get_detailed_info()
  local stats = Macros.get_stats()
  local paths = Macros.get_search_paths()

  local cb = ContentBuilder.new()

  -- Header
  cb:header("ETL Macro Library")
  cb:separator("─", 70)
  cb:blank()

  -- Search paths
  cb:section("Search Paths")
  for _, p in ipairs(paths) do
    local icon = p.exists and "✓" or "✗"
    local icon_style = p.exists and "success" or "error"
    cb:spans({
      { text = "  " },
      { text = icon, style = icon_style },
      { text = " [" },
      { text = p.source, style = "info" },
      { text = "] " },
      { text = p.path, style = p.exists and "muted" or "error" },
    })
  end

  cb:blank()

  -- Stats
  cb:spans({
    { text = "Loaded: " },
    { text = tostring(stats.macro_count), style = "number" },
    { text = " macros from " },
    { text = tostring(stats.file_count), style = "number" },
    { text = " files" },
  })

  if stats.error_count > 0 then
    cb:spans({
      { text = "Errors: " },
      { text = tostring(stats.error_count), style = "error" },
    })
  end

  cb:blank()
  cb:separator("─", 70)
  cb:blank()

  -- Macro list
  if #info == 0 then
    cb:styled("No macros loaded.", "muted")
  else
    cb:section("Available Macros")
    cb:blank()

    -- Group by source
    local by_source = {}
    for _, m in ipairs(info) do
      by_source[m.source] = by_source[m.source] or {}
      table.insert(by_source[m.source], m)
    end

    local source_styles = {
      builtin = "muted",
      user = "info",
      custom = "warning",
      project = "success",
    }

    local source_order = { "builtin", "user", "custom", "project" }
    for _, source in ipairs(source_order) do
      local macros_in_source = by_source[source]
      if macros_in_source and #macros_in_source > 0 then
        cb:spans({
          { text = "  [" },
          { text = source:upper(), style = source_styles[source] or "muted" },
          { text = "]" },
        })

        for _, m in ipairs(macros_in_source) do
          local file_short = vim.fn.fnamemodify(m.file, ":t")
          cb:spans({
            { text = "    • " },
            { text = "macros.", style = "muted" },
            { text = m.name, style = "function" },
            { text = "  (" .. file_short .. ")", style = "comment" },
          })
        end
        cb:blank()
      end
    end
  end

  -- Show errors if any
  local errors = Macros.get_errors()
  if #errors > 0 then
    cb:separator("─", 70)
    cb:blank()
    cb:styled("Loading Errors:", "error")
    for _, err in ipairs(errors) do
      cb:styled("  " .. vim.fn.fnamemodify(err.file, ":t"), "warning")
      cb:styled("    " .. err.error, "error")
    end
  end

  -- Display in a floating window
  local Float = require('nvim-float.window')
  local win = Float.create_styled(cb, {
    title = "ETL Macros",
    min_width = 80,
    max_height = 40,
    center = true,
    focusable = true,
    footer = "q: close | :SSNSMacrosReload to refresh",
  })

  if win then
    vim.keymap.set("n", "q", function() win:close() end, { buffer = win.buf, nowait = true })
    vim.keymap.set("n", "<Esc>", function() win:close() end, { buffer = win.buf, nowait = true })
  end
end

---Register all ETL commands
function M.setup()
  -- Main execution command
  vim.api.nvim_create_user_command("SSNSEtl", function(opts)
    if opts.args == "dry" or opts.args == "dryrun" then
      M.execute({ dry_run = true })
    else
      M.execute()
    end
  end, {
    desc = "Execute ETL script in current buffer",
    nargs = "?",
    complete = function()
      return { "dry", "dryrun" }
    end,
  })

  -- Single block execution
  vim.api.nvim_create_user_command("SSNSEtlBlock", function()
    M.execute_block()
  end, {
    desc = "Execute ETL block under cursor",
  })

  -- Validation
  vim.api.nvim_create_user_command("SSNSEtlValidate", function()
    M.validate()
  end, {
    desc = "Validate ETL script without executing",
  })

  -- Dry run / execution plan
  vim.api.nvim_create_user_command("SSNSEtlDryRun", function()
    M.show_execution_plan()
  end, {
    desc = "Show ETL execution plan without running",
  })

  -- Cancel
  vim.api.nvim_create_user_command("SSNSEtlCancel", function()
    M.cancel()
  end, {
    desc = "Cancel running ETL execution",
  })

  -- Macro commands
  vim.api.nvim_create_user_command("SSNSMacrosReload", function()
    M.macros_reload()
  end, {
    desc = "Reload ETL macro library",
  })

  vim.api.nvim_create_user_command("SSNSMacrosList", function()
    M.macros_list()
  end, {
    desc = "List loaded ETL macros",
  })

  -- Initialize macros on setup
  Macros.setup()
end

return M
