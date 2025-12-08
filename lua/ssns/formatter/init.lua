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

---Format a range of text in the current buffer
---@param start_line number Start line (1-indexed)
---@param end_line number End line (1-indexed)
---@return boolean success
---@return string? error
function Formatter.format_range(start_line, end_line)
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

return Formatter
