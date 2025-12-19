--- Async Operation Benchmarks
--- Compares sync vs async performance for various operations
local M = {}

local runner = require("ssns.testing.benchmarks.runner")

--- Generate test data
--- @param size number Size in bytes
--- @return string data
local function generate_data(size)
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  local result = {}
  for i = 1, size do
    local idx = math.random(1, #chars)
    result[i] = chars:sub(idx, idx)
  end
  return table.concat(result)
end

--- Generate test SQL
--- @param statement_count number Number of SELECT statements
--- @return string sql
local function generate_sql(statement_count)
  local statements = {}
  for i = 1, statement_count do
    table.insert(statements, string.format(
      "SELECT Column1, Column2, Column3 FROM Table%d WHERE ID = %d AND Status = 'active';",
      i % 10, i
    ))
  end
  return table.concat(statements, "\n")
end

-- ============================================================================
-- File I/O Benchmarks
-- ============================================================================

--- Create file I/O benchmarks
--- @return table[] benchmarks
function M.create_file_io_benchmarks()
  local FileIO = require("ssns.async.file_io")
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")

  local benchmarks = {}

  -- Small file read (1KB)
  local small_file = temp_dir .. "/small.txt"
  local small_data = generate_data(1024)
  vim.fn.writefile({ small_data }, small_file)

  table.insert(benchmarks, {
    name = "File Read - 1KB",
    sync_fn = function()
      return vim.fn.readfile(small_file)
    end,
    async_fn = function(callback)
      FileIO.read_async(small_file, function(result)
        callback(result)
      end)
    end,
  })

  -- Medium file read (100KB)
  local medium_file = temp_dir .. "/medium.txt"
  local medium_data = generate_data(100 * 1024)
  vim.fn.writefile({ medium_data }, medium_file)

  table.insert(benchmarks, {
    name = "File Read - 100KB",
    sync_fn = function()
      return vim.fn.readfile(medium_file)
    end,
    async_fn = function(callback)
      FileIO.read_async(medium_file, function(result)
        callback(result)
      end)
    end,
  })

  -- Large file read (1MB)
  local large_file = temp_dir .. "/large.txt"
  local large_data = generate_data(1024 * 1024)
  vim.fn.writefile({ large_data }, large_file)

  table.insert(benchmarks, {
    name = "File Read - 1MB",
    sync_fn = function()
      return vim.fn.readfile(large_file)
    end,
    async_fn = function(callback)
      FileIO.read_async(large_file, function(result)
        callback(result)
      end)
    end,
  })

  -- File write benchmarks
  local write_small = temp_dir .. "/write_small.txt"
  table.insert(benchmarks, {
    name = "File Write - 1KB",
    sync_fn = function()
      vim.fn.writefile({ small_data }, write_small)
    end,
    async_fn = function(callback)
      FileIO.write_async(write_small, small_data, function(result)
        callback(result)
      end)
    end,
  })

  local write_large = temp_dir .. "/write_large.txt"
  table.insert(benchmarks, {
    name = "File Write - 1MB",
    sync_fn = function()
      vim.fn.writefile({ large_data }, write_large)
    end,
    async_fn = function(callback)
      FileIO.write_async(write_large, large_data, function(result)
        callback(result)
      end)
    end,
  })

  -- Store temp_dir for cleanup
  benchmarks._temp_dir = temp_dir

  return benchmarks
end

-- ============================================================================
-- Formatter Benchmarks
-- ============================================================================

--- Create formatter benchmarks
--- @return table[] benchmarks
function M.create_formatter_benchmarks()
  local Formatter = require("ssns.formatter")
  local benchmarks = {}

  -- Small SQL (10 statements)
  local small_sql = generate_sql(10)
  table.insert(benchmarks, {
    name = "SQL Format - 10 statements",
    sync_fn = function()
      return Formatter.format(small_sql)
    end,
    async_fn = function(callback)
      Formatter.format_async(small_sql, nil, {
        on_complete = function(formatted)
          callback(formatted)
        end,
      })
    end,
  })

  -- Medium SQL (50 statements)
  local medium_sql = generate_sql(50)
  table.insert(benchmarks, {
    name = "SQL Format - 50 statements",
    sync_fn = function()
      return Formatter.format(medium_sql)
    end,
    async_fn = function(callback)
      Formatter.format_async(medium_sql, nil, {
        on_complete = function(formatted)
          callback(formatted)
        end,
      })
    end,
  })

  -- Large SQL (200 statements)
  local large_sql = generate_sql(200)
  table.insert(benchmarks, {
    name = "SQL Format - 200 statements",
    sync_fn = function()
      return Formatter.format(large_sql)
    end,
    async_fn = function(callback)
      Formatter.format_async(large_sql, nil, {
        on_complete = function(formatted)
          callback(formatted)
        end,
      })
    end,
  })

  return benchmarks
end

-- ============================================================================
-- Completion Benchmarks
-- ============================================================================

--- Create completion benchmarks (async only since completion is fundamentally async)
--- @return table[] benchmarks
function M.create_completion_benchmarks()
  local benchmarks = {}

  -- These require a connected database, so we'll create placeholder benchmarks
  -- that test the completion infrastructure without actual DB queries

  local Source = require("ssns.completion.source")
  local StatementParser = require("ssns.completion.statement_parser")

  -- Statement parsing benchmark
  local small_query = "SELECT * FROM Employees WHERE EmployeeID = 1"
  local large_query = generate_sql(100)

  table.insert(benchmarks, {
    name = "Statement Parse - Small Query",
    async_only = true,
    async_fn = function(callback)
      vim.schedule(function()
        local result = StatementParser.parse(small_query)
        callback(result)
      end)
    end,
  })

  table.insert(benchmarks, {
    name = "Statement Parse - Large Query (100 statements)",
    async_only = true,
    async_fn = function(callback)
      vim.schedule(function()
        local result = StatementParser.parse(large_query)
        callback(result)
      end)
    end,
  })

  -- Tokenizer benchmark
  local Tokenizer = require("ssns.completion.tokenizer")

  table.insert(benchmarks, {
    name = "Tokenize - Small Query",
    async_only = true,
    async_fn = function(callback)
      vim.schedule(function()
        local tokens = Tokenizer.tokenize(small_query)
        callback(tokens)
      end)
    end,
  })

  table.insert(benchmarks, {
    name = "Tokenize - Large Query",
    async_only = true,
    async_fn = function(callback)
      vim.schedule(function()
        local tokens = Tokenizer.tokenize(large_query)
        callback(tokens)
      end)
    end,
  })

  return benchmarks
end

-- ============================================================================
-- Chunked Rendering Benchmarks
-- ============================================================================

--- Create chunked rendering benchmarks
--- @return table[] benchmarks
function M.create_rendering_benchmarks()
  local benchmarks = {}

  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Generate test lines
  local function generate_lines(count)
    local lines = {}
    for i = 1, count do
      lines[i] = string.format("Line %d: This is test content for benchmarking buffer operations", i)
    end
    return lines
  end

  -- Small buffer (100 lines)
  local small_lines = generate_lines(100)
  table.insert(benchmarks, {
    name = "Buffer Write - 100 lines (sync)",
    sync_fn = function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, small_lines)
    end,
    async_fn = function(callback)
      local UiBuffer = require("ssns.ui.core.buffer")
      if UiBuffer.set_lines_chunked then
        UiBuffer.set_lines_chunked(bufnr, 0, -1, false, small_lines, {
          on_complete = function()
            callback(true)
          end,
        })
      else
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, small_lines)
        callback(true)
      end
    end,
  })

  -- Medium buffer (500 lines)
  local medium_lines = generate_lines(500)
  table.insert(benchmarks, {
    name = "Buffer Write - 500 lines",
    sync_fn = function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, medium_lines)
    end,
    async_fn = function(callback)
      local UiBuffer = require("ssns.ui.core.buffer")
      if UiBuffer.set_lines_chunked then
        UiBuffer.set_lines_chunked(bufnr, 0, -1, false, medium_lines, {
          on_complete = function()
            callback(true)
          end,
        })
      else
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, medium_lines)
        callback(true)
      end
    end,
  })

  -- Large buffer (2000 lines)
  local large_lines = generate_lines(2000)
  table.insert(benchmarks, {
    name = "Buffer Write - 2000 lines",
    sync_fn = function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, large_lines)
    end,
    async_fn = function(callback)
      local UiBuffer = require("ssns.ui.core.buffer")
      if UiBuffer.set_lines_chunked then
        UiBuffer.set_lines_chunked(bufnr, 0, -1, false, large_lines, {
          on_complete = function()
            callback(true)
          end,
        })
      else
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, large_lines)
        callback(true)
      end
    end,
  })

  -- Store bufnr for cleanup
  benchmarks._bufnr = bufnr

  return benchmarks
end

-- ============================================================================
-- Main Benchmark Suite
-- ============================================================================

--- Run all async benchmarks
--- @param opts table? Options { iterations: number, warmup: number }
--- @return string report
function M.run_all(opts)
  opts = opts or {}
  opts.iterations = opts.iterations or 5
  opts.warmup = opts.warmup or 1

  vim.notify("Starting SSNS Async Benchmarks...", vim.log.levels.INFO)

  local all_benchmarks = {}

  -- File I/O
  vim.notify("Creating File I/O benchmarks...", vim.log.levels.INFO)
  local file_benchmarks = M.create_file_io_benchmarks()
  for _, b in ipairs(file_benchmarks) do
    table.insert(all_benchmarks, b)
  end

  -- Formatter
  vim.notify("Creating Formatter benchmarks...", vim.log.levels.INFO)
  local formatter_benchmarks = M.create_formatter_benchmarks()
  for _, b in ipairs(formatter_benchmarks) do
    table.insert(all_benchmarks, b)
  end

  -- Completion infrastructure
  vim.notify("Creating Completion benchmarks...", vim.log.levels.INFO)
  local completion_benchmarks = M.create_completion_benchmarks()
  for _, b in ipairs(completion_benchmarks) do
    table.insert(all_benchmarks, b)
  end

  -- Rendering
  vim.notify("Creating Rendering benchmarks...", vim.log.levels.INFO)
  local rendering_benchmarks = M.create_rendering_benchmarks()
  for _, b in ipairs(rendering_benchmarks) do
    table.insert(all_benchmarks, b)
  end

  -- Run benchmarks
  local report = runner.run_all(all_benchmarks, opts)

  -- Cleanup
  if file_benchmarks._temp_dir then
    vim.fn.delete(file_benchmarks._temp_dir, "rf")
  end
  if rendering_benchmarks._bufnr then
    pcall(vim.api.nvim_buf_delete, rendering_benchmarks._bufnr, { force = true })
  end

  -- Save report
  runner.save_report(report)

  vim.notify("Benchmarks complete!", vim.log.levels.INFO)

  return report
end

--- Run a specific category of benchmarks
--- @param category string Category name: "file_io", "formatter", "completion", "rendering"
--- @param opts table? Options
--- @return string report
function M.run_category(category, opts)
  opts = opts or {}
  opts.iterations = opts.iterations or 5
  opts.warmup = opts.warmup or 1

  local benchmarks
  if category == "file_io" then
    benchmarks = M.create_file_io_benchmarks()
  elseif category == "formatter" then
    benchmarks = M.create_formatter_benchmarks()
  elseif category == "completion" then
    benchmarks = M.create_completion_benchmarks()
  elseif category == "rendering" then
    benchmarks = M.create_rendering_benchmarks()
  else
    vim.notify("Unknown category: " .. category, vim.log.levels.ERROR)
    return ""
  end

  local report = runner.run_all(benchmarks, opts)

  -- Cleanup
  if benchmarks._temp_dir then
    vim.fn.delete(benchmarks._temp_dir, "rf")
  end
  if benchmarks._bufnr then
    pcall(vim.api.nvim_buf_delete, benchmarks._bufnr, { force = true })
  end

  return report
end

return M
