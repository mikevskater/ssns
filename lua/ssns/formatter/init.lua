---@class Formatter
---SQL Formatter module - main entry point for SQL formatting functionality.
---Uses the existing tokenizer and statement parser to provide intelligent,
---configurable SQL formatting with best-effort error handling.
---
---@field config FormatterConfig Current formatter configuration
local Formatter = {}

---Format SQL text with current configuration
---@param sql string The SQL text to format
---@param config_override? FormatterConfig Optional config override (uses global config if nil)
---@param opts? {dialect?: string} Optional formatting options
---@return string formatted The formatted SQL text
function Formatter.format(sql, config_override, opts)
  local Engine = require('ssns.formatter.engine')
  local config = config_override or require('ssns.config').get_formatter()
  return Engine.format(sql, config, opts)
end

---@class FormatAsyncCallbackOpts
---@field on_progress fun(stage: string, progress: number, total: number)? Progress callback
---@field on_complete fun(formatted: string)? Completion callback (required)
---@field on_error fun(err: string)? Error callback

---Format SQL text asynchronously
---@param sql string The SQL text to format
---@param config_override? FormatterConfig Optional config override
---@param opts? FormatAsyncCallbackOpts Async options with callbacks
function Formatter.format_async(sql, config_override, opts)
  local Engine = require('ssns.formatter.engine')
  local config = config_override or require('ssns.config').get_formatter()
  opts = opts or {}

  Engine.format_async(sql, config, {
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Format a range of text in the current buffer
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean success
---@return string? error
function Formatter.format_range(start_line, end_line)
  local config = require('ssns.config').get_formatter()

  -- Pre-processing: Expand asterisks if enabled
  -- This modifies the buffer in-place before formatting
  if config.select_star_expand then
    local ok, ExpandAsterisk = pcall(require, 'ssns.features.expand_asterisk')
    if ok then
      local expand_result = ExpandAsterisk.expand_all_asterisks_in_range(0, start_line, end_line)
      if expand_result.expanded_count > 0 then
        -- Re-calculate end_line as expansion may have changed line count
        -- (though current implementation stays on same line)
        -- For safety, re-fetch the line count
        local line_count = vim.api.nvim_buf_line_count(0)
        end_line = math.min(end_line, line_count)
      end
    end
  end

  -- Pre-processing: Add schema prefixes if from_schema_qualify = "always"
  -- This modifies the buffer in-place before formatting
  -- Note: "never" mode is handled in the transform pass (07_transform.lua)
  if config.from_schema_qualify == "always" then
    local ok, SchemaQualify = pcall(require, 'ssns.features.schema_qualify')
    if ok then
      local qualify_result = SchemaQualify.qualify_tables_in_range(0, start_line, end_line)
      if qualify_result.qualified_count > 0 then
        -- Re-fetch line count in case modifications changed it
        local line_count = vim.api.nvim_buf_line_count(0)
        end_line = math.min(end_line, line_count)
      end
    end
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local sql = table.concat(lines, "\n")

  local ok, result = pcall(Formatter.format, sql)
  if not ok then
    return false, result
  end

  local new_lines = vim.split(result, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
  return true, nil
end

---Format the entire current buffer
---@return boolean success
---@return string? error
function Formatter.format_buffer()
  local line_count = vim.api.nvim_buf_line_count(0)
  return Formatter.format_range(1, line_count)
end

---@class FormatBufferAsyncOpts
---@field on_progress fun(stage: string, progress: number, total: number)? Progress callback
---@field on_complete fun(success: boolean, err?: string)? Completion callback
---@field bufnr number? Buffer number (default: current buffer)

---Format the entire buffer asynchronously
---@param opts? FormatBufferAsyncOpts Async options
function Formatter.format_buffer_async(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  Formatter.format_range_async(1, line_count, {
    bufnr = bufnr,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---@class FormatRangeAsyncOpts
---@field on_progress fun(stage: string, progress: number, total: number)? Progress callback
---@field on_complete fun(success: boolean, err?: string)? Completion callback
---@field bufnr number? Buffer number (default: current buffer)

---Format a range of text in a buffer asynchronously
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@param opts? FormatRangeAsyncOpts Async options
function Formatter.format_range_async(start_line, end_line, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete

  local config = require('ssns.config').get_formatter()
  local Engine = require('ssns.formatter.engine')

  -- Capture original end_line before any modifications
  local original_end_line = end_line

  -- Pre-processing: Expand asterisks if enabled (sync, usually fast)
  if config.select_star_expand then
    local ok, ExpandAsterisk = pcall(require, 'ssns.features.expand_asterisk')
    if ok then
      local expand_result = ExpandAsterisk.expand_all_asterisks_in_range(bufnr, start_line, end_line)
      if expand_result.expanded_count > 0 then
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        end_line = math.min(end_line, line_count)
      end
    end
  end

  -- Pre-processing: Add schema prefixes if from_schema_qualify = "always" (sync, usually fast)
  if config.from_schema_qualify == "always" then
    local ok, SchemaQualify = pcall(require, 'ssns.features.schema_qualify')
    if ok then
      local qualify_result = SchemaQualify.qualify_tables_in_range(bufnr, start_line, end_line)
      if qualify_result.qualified_count > 0 then
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        end_line = math.min(end_line, line_count)
      end
    end
  end

  -- Get buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local sql = table.concat(lines, "\n")

  -- Format asynchronously
  Engine.format_async(sql, config, {
    on_progress = on_progress,
    on_complete = function(formatted)
      -- Apply the formatted result to the buffer
      vim.schedule(function()
        -- Check if buffer is still valid
        if not vim.api.nvim_buf_is_valid(bufnr) then
          if on_complete then on_complete(false, "Buffer is no longer valid") end
          return
        end

        local ok, err = pcall(function()
          local new_lines = vim.split(formatted, "\n", { plain = true })
          vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
        end)

        if on_complete then
          if ok then
            on_complete(true, nil)
          else
            on_complete(false, tostring(err))
          end
        end
      end)
    end,
  })
end

---Format the SQL statement under the cursor
---@return boolean success
---@return string? error
function Formatter.format_statement()
  local StatementParser = require('ssns.completion.statement_parser')
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local full_text = table.concat(lines, "\n")

  local chunks = StatementParser.parse(full_text)
  if not chunks or #chunks == 0 then
    return false, "No SQL statement found"
  end

  -- Find the chunk containing the cursor
  for _, chunk in ipairs(chunks) do
    if chunk.start_line and chunk.end_line then
      if line >= chunk.start_line and line <= chunk.end_line then
        return Formatter.format_range(chunk.start_line, chunk.end_line)
      end
    end
  end

  return false, "Cursor is not within a SQL statement"
end

---Check if formatter is enabled
---@return boolean
function Formatter.is_enabled()
  local config = require('ssns.config').get_formatter()
  return config.enabled
end

---Get the current formatter configuration
---@return FormatterConfig
function Formatter.get_config()
  return require('ssns.config').get_formatter()
end

---Get performance statistics summary
---@return table
function Formatter.get_stats()
  local Stats = require('ssns.formatter.stats')
  return Stats.get_summary()
end

---Reset performance statistics
function Formatter.reset_stats()
  local Stats = require('ssns.formatter.stats')
  Stats.reset()
end

---Get formatted stats display
---@return string
function Formatter.format_stats()
  local Stats = require('ssns.formatter.stats')
  return Stats.format_summary()
end

---Run benchmarks
---@param opts? table Benchmark options
---@return table[] results
function Formatter.run_benchmarks(opts)
  local Benchmark = require('ssns.formatter.benchmark')
  return Benchmark.run_suite(opts)
end

---Format benchmark results for display
---@param results table[] Benchmark results
---@return string
function Formatter.format_benchmark_results(results)
  local Benchmark = require('ssns.formatter.benchmark')
  return Benchmark.format_results(results)
end

---Clear the token cache
function Formatter.clear_cache()
  local Engine = require('ssns.formatter.engine')
  Engine.cache.clear()
end

---Cancel any in-progress async formatting
function Formatter.cancel_async_formatting()
  local Engine = require('ssns.formatter.engine')
  Engine.cancel_async_formatting()
end

---Check if async formatting is currently in progress
---@return boolean
function Formatter.is_async_formatting_active()
  local Engine = require('ssns.formatter.engine')
  return Engine.is_async_formatting_active()
end

return Formatter
