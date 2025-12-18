---@class FormatterCommands
---SQL Formatter commands and keymaps for Neovim integration.
---Provides :SSNSFormat, :SSNSFormatRange, :SSNSFormatStatement commands
---and configurable keymaps for SQL buffer formatting.
local FormatterCommands = {}

local Formatter = require('ssns.formatter')
local Config = require('ssns.config')
local KeymapManager = require('ssns.keymap_manager')

---Notify user of format result
---@param success boolean Whether formatting succeeded
---@param err string? Error message if failed
---@param context string? Context description (e.g., "buffer", "selection", "statement")
local function notify_result(success, err, context)
  context = context or "SQL"
  if success then
    vim.notify(string.format("SSNS: Formatted %s", context), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Format failed: %s", err or "Unknown error"), vim.log.levels.ERROR)
  end
end

---Format the entire buffer
---@param opts? {silent?: boolean} Options
function FormatterCommands.format_buffer(opts)
  opts = opts or {}

  if not Formatter.is_enabled() then
    if not opts.silent then
      vim.notify("SSNS: Formatter is disabled", vim.log.levels.WARN)
    end
    return
  end

  -- Save cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_count_before = vim.api.nvim_buf_line_count(0)

  local success, err = Formatter.format_buffer()

  -- Restore cursor position (adjust if line count changed)
  local line_count_after = vim.api.nvim_buf_line_count(0)
  local new_line = math.min(cursor[1], line_count_after)
  local new_col = cursor[2]

  -- Try to get the line length to ensure we don't go past end of line
  local line_text = vim.api.nvim_buf_get_lines(0, new_line - 1, new_line, false)[1] or ""
  new_col = math.min(new_col, #line_text)

  pcall(vim.api.nvim_win_set_cursor, 0, { new_line, new_col })

  if not opts.silent then
    notify_result(success, err, "buffer")
  end

  return success
end

---Active spinner ID for formatting progress
---@type string?
local _format_spinner_id = nil

---Stage display names for progress
local STAGE_NAMES = {
  tokenizing = "Tokenizing",
  processing = "Processing tokens",
  passes = "Running passes",
  output = "Generating output",
  cache = "Loading from cache",
}

---Format the entire buffer asynchronously with progress indicator
---@param opts? {silent?: boolean, show_spinner?: boolean} Options
function FormatterCommands.format_buffer_async(opts)
  opts = opts or {}
  local show_spinner = opts.show_spinner ~= false -- Default true

  if not Formatter.is_enabled() then
    if not opts.silent then
      vim.notify("SSNS: Formatter is disabled", vim.log.levels.WARN)
    end
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  -- Start spinner if enabled
  if show_spinner then
    local Spinner = require('ssns.async.spinner')

    -- Stop any existing spinner
    if _format_spinner_id then
      Spinner.stop(_format_spinner_id)
    end

    _format_spinner_id = Spinner.start_in_buffer(bufnr, {
      text = "Formatting...",
      line = cursor[1] - 1, -- 0-indexed
      style = "braille",
      show_runtime = true,
    })
  end

  -- Start async formatting
  Formatter.format_buffer_async({
    bufnr = bufnr,
    on_progress = function(stage, progress, total)
      if show_spinner and _format_spinner_id then
        local Spinner = require('ssns.async.spinner')
        local stage_name = STAGE_NAMES[stage] or stage
        local pct = total > 0 and math.floor((progress / total) * 100) or 0
        Spinner.update(_format_spinner_id, string.format("Formatting: %s %d%%", stage_name, pct))
      end
    end,
    on_complete = function(success, err)
      -- Stop spinner
      if show_spinner and _format_spinner_id then
        local Spinner = require('ssns.async.spinner')
        Spinner.stop(_format_spinner_id)
        _format_spinner_id = nil
      end

      -- Restore cursor position
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then return end

        local line_count_after = vim.api.nvim_buf_line_count(bufnr)
        local new_line = math.min(cursor[1], line_count_after)
        local new_col = cursor[2]

        local line_text = vim.api.nvim_buf_get_lines(bufnr, new_line - 1, new_line, false)[1] or ""
        new_col = math.min(new_col, #line_text)

        pcall(vim.api.nvim_win_set_cursor, 0, { new_line, new_col })

        if not opts.silent then
          notify_result(success, err, "buffer")
        end
      end)
    end,
  })
end

---Format a range asynchronously with progress indicator
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@param opts? {silent?: boolean, show_spinner?: boolean} Options
function FormatterCommands.format_range_async(start_line, end_line, opts)
  opts = opts or {}
  local show_spinner = opts.show_spinner ~= false

  if not Formatter.is_enabled() then
    if not opts.silent then
      vim.notify("SSNS: Formatter is disabled", vim.log.levels.WARN)
    end
    return
  end

  -- Ensure start <= end
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Start spinner if enabled
  if show_spinner then
    local Spinner = require('ssns.async.spinner')

    if _format_spinner_id then
      Spinner.stop(_format_spinner_id)
    end

    _format_spinner_id = Spinner.start_in_buffer(bufnr, {
      text = "Formatting...",
      line = start_line - 1,
      style = "braille",
      show_runtime = true,
    })
  end

  Formatter.format_range_async(start_line, end_line, {
    bufnr = bufnr,
    on_progress = function(stage, progress, total)
      if show_spinner and _format_spinner_id then
        local Spinner = require('ssns.async.spinner')
        local stage_name = STAGE_NAMES[stage] or stage
        local pct = total > 0 and math.floor((progress / total) * 100) or 0
        Spinner.update(_format_spinner_id, string.format("Formatting: %s %d%%", stage_name, pct))
      end
    end,
    on_complete = function(success, err)
      if show_spinner and _format_spinner_id then
        local Spinner = require('ssns.async.spinner')
        Spinner.stop(_format_spinner_id)
        _format_spinner_id = nil
      end

      if not opts.silent then
        vim.schedule(function()
          notify_result(success, err, string.format("lines %d-%d", start_line, end_line))
        end)
      end
    end,
  })
end

---Cancel any in-progress async formatting
function FormatterCommands.cancel_async_format()
  -- Stop spinner
  if _format_spinner_id then
    local Spinner = require('ssns.async.spinner')
    Spinner.stop(_format_spinner_id)
    _format_spinner_id = nil
  end

  -- Cancel async formatting
  Formatter.cancel_async_formatting()
  vim.notify("SSNS: Formatting cancelled", vim.log.levels.INFO)
end

---Format a visual selection (range)
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@param opts? {silent?: boolean} Options
function FormatterCommands.format_range(start_line, end_line, opts)
  opts = opts or {}

  if not Formatter.is_enabled() then
    if not opts.silent then
      vim.notify("SSNS: Formatter is disabled", vim.log.levels.WARN)
    end
    return
  end

  -- Ensure start <= end
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local success, err = Formatter.format_range(start_line, end_line)

  if not opts.silent then
    notify_result(success, err, string.format("lines %d-%d", start_line, end_line))
  end

  return success
end

---Format the SQL statement under the cursor
---@param opts? {silent?: boolean} Options
function FormatterCommands.format_statement(opts)
  opts = opts or {}

  if not Formatter.is_enabled() then
    if not opts.silent then
      vim.notify("SSNS: Formatter is disabled", vim.log.levels.WARN)
    end
    return
  end

  -- Save cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)

  local success, err = Formatter.format_statement()

  -- Try to restore cursor position
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)

  if not opts.silent then
    notify_result(success, err, "statement")
  end

  return success
end

---Show formatter performance statistics
function FormatterCommands.show_stats()
  local Stats = require('ssns.formatter.stats')
  local UiFloat = require('ssns.ui.core.float')
  local ContentBuilder = require('ssns.ui.core.content_builder')
  
  local output = Stats.format_summary()
  local raw_lines = vim.split(output, "\n")
  
  -- Build styled content
  local cb = ContentBuilder.new()
  
  for _, line in ipairs(raw_lines) do
    -- Style headers
    if line:match("^===") or line:match("^%-%-%-") then
      cb:styled(line, "muted")
    elseif line:match("^[A-Z][a-z]+:$") then
      cb:section(line)
    elseif line:match("^  [A-Za-z]+:") then
      -- Key-value style lines
      local key, value = line:match("^  ([^:]+):%s*(.+)$")
      if key and value then
        cb:spans({
          { text = "  " },
          { text = key, style = "label" },
          { text = ": " },
          { text = value, style = "value" },
        })
      else
        cb:line(line)
      end
    elseif line == "" then
      cb:blank()
    else
      cb:line(line)
    end
  end

  UiFloat.create_styled(cb, {
    title = "Formatter Stats",
    min_width = 60,
    max_height = 25,
    footer = "q/Esc: close",
  })
end

---Reset formatter statistics
function FormatterCommands.reset_stats()
  local Stats = require('ssns.formatter.stats')
  Stats.reset()
  vim.notify("SSNS: Formatter stats reset", vim.log.levels.INFO)
end

---Run formatter benchmarks
---@param opts? {sizes?: string[]} Options
function FormatterCommands.run_benchmark(opts)
  opts = opts or {}
  local Benchmark = require('ssns.formatter.benchmark')
  Benchmark.run_and_display(opts)
end

---Clear the token cache
function FormatterCommands.clear_cache()
  local Engine = require('ssns.formatter.engine')
  Engine.cache.clear()
  vim.notify("SSNS: Formatter cache cleared", vim.log.levels.INFO)
end

---Open formatter configuration UI
function FormatterCommands.open_config()
  local RulesEditor = require('ssns.formatter.rules_editor')
  RulesEditor.show()
end

---Register formatter commands
function FormatterCommands.register_commands()
  -- :SSNSFormat - Format entire buffer
  vim.api.nvim_create_user_command("SSNSFormat", function()
    FormatterCommands.format_buffer()
  end, {
    desc = "Format entire SQL buffer",
  })

  -- :SSNSFormatAsync - Format entire buffer asynchronously with progress
  vim.api.nvim_create_user_command("SSNSFormatAsync", function()
    FormatterCommands.format_buffer_async()
  end, {
    desc = "Format entire SQL buffer asynchronously",
  })

  -- :SSNSFormatCancel - Cancel in-progress async formatting
  vim.api.nvim_create_user_command("SSNSFormatCancel", function()
    FormatterCommands.cancel_async_format()
  end, {
    desc = "Cancel in-progress async formatting",
  })

  -- :SSNSFormatterConfig - Open formatter configuration UI
  vim.api.nvim_create_user_command("SSNSFormatterConfig", function()
    FormatterCommands.open_config()
  end, {
    desc = "Open formatter configuration UI",
  })

  -- :SSNSFormatRange - Format visual selection
  -- This command receives the range from visual mode
  vim.api.nvim_create_user_command("SSNSFormatRange", function(opts)
    FormatterCommands.format_range(opts.line1, opts.line2)
  end, {
    range = true,
    desc = "Format selected SQL range",
  })

  -- :SSNSFormatRangeAsync - Format visual selection asynchronously
  vim.api.nvim_create_user_command("SSNSFormatRangeAsync", function(opts)
    FormatterCommands.format_range_async(opts.line1, opts.line2)
  end, {
    range = true,
    desc = "Format selected SQL range asynchronously",
  })

  -- :SSNSFormatStatement - Format statement under cursor
  vim.api.nvim_create_user_command("SSNSFormatStatement", function()
    FormatterCommands.format_statement()
  end, {
    desc = "Format SQL statement under cursor",
  })

  -- :SSNSFormatterStats - Show performance statistics
  vim.api.nvim_create_user_command("SSNSFormatterStats", function()
    FormatterCommands.show_stats()
  end, {
    desc = "Show formatter performance statistics",
  })

  -- :SSNSFormatterStatsReset - Reset performance statistics
  vim.api.nvim_create_user_command("SSNSFormatterStatsReset", function()
    FormatterCommands.reset_stats()
  end, {
    desc = "Reset formatter performance statistics",
  })

  -- :SSNSFormatterBenchmark - Run benchmarks
  vim.api.nvim_create_user_command("SSNSFormatterBenchmark", function()
    FormatterCommands.run_benchmark()
  end, {
    desc = "Run formatter benchmarks",
  })

  -- :SSNSFormatterCacheReset - Clear token cache
  vim.api.nvim_create_user_command("SSNSFormatterCacheReset", function()
    FormatterCommands.clear_cache()
  end, {
    desc = "Clear formatter token cache",
  })
end

---Buffers with pending async format-on-save
---@type table<number, boolean>
local _pending_format_save = {}

---Setup format-on-save autocmd for SQL buffers
---For small files, uses sync formatting in BufWritePre.
---For large files (above async_threshold_bytes), uses async formatting after save.
---@param bufnr number? Buffer number (nil for current buffer)
function FormatterCommands.setup_format_on_save(bufnr)
  local config = Config.get_formatter()

  if not config.format_on_save then
    return
  end

  -- Create autocmd group if not exists
  local group = vim.api.nvim_create_augroup("SSNSFormatterAutoSave", { clear = false })

  -- Setup BufWritePre autocmd for the buffer (sync formatting for small files)
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = bufnr,
    callback = function(ev)
      -- Only format if formatter is enabled
      if not Formatter.is_enabled() then
        return
      end

      -- Skip if this is a save after async format
      if _pending_format_save[ev.buf] then
        _pending_format_save[ev.buf] = nil
        return
      end

      -- Check file size
      local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      local size = 0
      for _, line in ipairs(lines) do
        size = size + #line + 1 -- +1 for newline
      end

      local async_threshold = config.async_threshold_bytes or 50000

      if size <= async_threshold then
        -- Small file: use sync formatting
        FormatterCommands.format_buffer({ silent = true })
      else
        -- Large file: schedule async format after save, then re-save
        -- Note: We don't block the write, format will happen after
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(ev.buf) then return end

          vim.notify("SSNS: Formatting large file asynchronously...", vim.log.levels.INFO)

          Formatter.format_buffer_async({
            bufnr = ev.buf,
            on_progress = function(stage, progress, total)
              -- Progress is shown via spinner
            end,
            on_complete = function(success, err)
              if success then
                -- Mark that we're about to save after async format
                _pending_format_save[ev.buf] = true

                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].modified then
                    -- Silent save after formatting
                    vim.api.nvim_buf_call(ev.buf, function()
                      vim.cmd("silent write")
                    end)
                    vim.notify("SSNS: Formatted and saved", vim.log.levels.INFO)
                  end
                end)
              else
                vim.notify(string.format("SSNS: Async format failed: %s", err or "Unknown error"), vim.log.levels.WARN)
              end
            end,
          })
        end)
      end
    end,
    desc = "SSNS: Format SQL on save",
  })
end

---Setup formatter keymaps for a buffer
---@param bufnr number Buffer number
function FormatterCommands.setup_keymaps(bufnr)
  -- Get keymaps using KeymapManager
  local format_buffer_key = KeymapManager.get('formatter', 'format_buffer')
  local format_statement_key = KeymapManager.get('formatter', 'format_statement')
  local open_config_key = KeymapManager.get('formatter', 'open_config')

  -- Build keymap definitions
  local keymaps = {}

  -- Format buffer keymap (normal mode)
  if format_buffer_key and format_buffer_key ~= "" then
    table.insert(keymaps, {
      mode = 'n',
      lhs = format_buffer_key,
      rhs = function()
        FormatterCommands.format_buffer()
      end,
      desc = 'SSNS: Format buffer',
    })

    -- Format visual selection keymap (uses the same key in visual mode)
    table.insert(keymaps, {
      mode = 'v',
      lhs = format_buffer_key,
      rhs = function()
        -- Get visual selection range
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")

        -- Exit visual mode first
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), 'n', false)

        -- Schedule the format to run after visual mode is exited
        vim.schedule(function()
          FormatterCommands.format_range(start_line, end_line)
        end)
      end,
      desc = 'SSNS: Format selection',
    })
  end

  -- Format statement keymap
  if format_statement_key and format_statement_key ~= "" then
    table.insert(keymaps, {
      mode = 'n',
      lhs = format_statement_key,
      rhs = function()
        FormatterCommands.format_statement()
      end,
      desc = 'SSNS: Format statement under cursor',
    })
  end

  -- Open config UI keymap
  if open_config_key and open_config_key ~= "" then
    table.insert(keymaps, {
      mode = 'n',
      lhs = open_config_key,
      rhs = function()
        FormatterCommands.open_config()
      end,
      desc = 'SSNS: Open formatter config',
    })
  end

  -- Set all keymaps using KeymapManager
  if #keymaps > 0 then
    KeymapManager.set_multiple(bufnr, keymaps, true)
    KeymapManager.mark_group_active(bufnr, 'formatter')
  end
end

---Setup formatter for a SQL buffer (keymaps + format-on-save)
---@param bufnr number Buffer number
function FormatterCommands.setup_buffer(bufnr)
  FormatterCommands.setup_keymaps(bufnr)
  FormatterCommands.setup_format_on_save(bufnr)
end

return FormatterCommands
