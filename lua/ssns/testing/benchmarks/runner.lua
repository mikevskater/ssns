--- Performance Benchmark Runner
--- Measures and compares sync vs async operation performance
local M = {}

---@class BenchmarkResult
---@field name string Benchmark name
---@field sync_times number[] Array of sync execution times (ms)
---@field async_times number[] Array of async execution times (ms)
---@field sync_avg number Average sync time (ms)
---@field async_avg number Average async time (ms)
---@field sync_min number Min sync time (ms)
---@field async_min number Min async time (ms)
---@field sync_max number Max sync time (ms)
---@field async_max number Max async time (ms)
---@field speedup number Speedup factor (sync_avg / async_avg)
---@field async_faster boolean True if async was faster
---@field iterations number Number of iterations run

--- High resolution timer using vim.loop.hrtime
--- @return number Current time in milliseconds
local function now_ms()
  return vim.loop.hrtime() / 1e6
end

--- Calculate statistics for an array of times
--- @param times number[] Array of times in ms
--- @return number avg Average
--- @return number min Minimum
--- @return number max Maximum
--- @return number stddev Standard deviation
local function calc_stats(times)
  if #times == 0 then
    return 0, 0, 0, 0
  end

  local sum = 0
  local min_val = times[1]
  local max_val = times[1]

  for _, t in ipairs(times) do
    sum = sum + t
    if t < min_val then min_val = t end
    if t > max_val then max_val = t end
  end

  local avg = sum / #times

  -- Calculate standard deviation
  local sq_sum = 0
  for _, t in ipairs(times) do
    sq_sum = sq_sum + (t - avg) ^ 2
  end
  local stddev = math.sqrt(sq_sum / #times)

  return avg, min_val, max_val, stddev
end

--- Create async waiter for benchmarks
--- @param timeout_ms number? Timeout in ms
--- @return function waiter
--- @return function signal
local function create_waiter(timeout_ms)
  timeout_ms = timeout_ms or 30000
  local done = false
  local result = nil

  return function()
    local start = now_ms()
    while not done do
      vim.wait(1, function() return done end, 1)
      if now_ms() - start > timeout_ms then
        return nil, "timeout"
      end
    end
    return result
  end, function(value)
    result = value
    done = true
  end
end

--- Run a benchmark comparing sync vs async
--- @param name string Benchmark name
--- @param sync_fn function Synchronous function to benchmark
--- @param async_fn function Async function (receives callback as last arg)
--- @param opts table? Options { iterations: number, warmup: number, timeout_ms: number }
--- @return BenchmarkResult result
function M.run_comparison(name, sync_fn, async_fn, opts)
  opts = opts or {}
  local iterations = opts.iterations or 10
  local warmup = opts.warmup or 2
  local timeout_ms = opts.timeout_ms or 30000

  local sync_times = {}
  local async_times = {}

  -- Warmup sync
  for _ = 1, warmup do
    pcall(sync_fn)
  end

  -- Warmup async
  for _ = 1, warmup do
    local waiter, signal = create_waiter(timeout_ms)
    pcall(function()
      async_fn(function() signal(true) end)
    end)
    waiter()
  end

  -- Benchmark sync
  for _ = 1, iterations do
    collectgarbage("collect")
    local start = now_ms()
    local ok, err = pcall(sync_fn)
    local elapsed = now_ms() - start
    if ok then
      table.insert(sync_times, elapsed)
    end
  end

  -- Benchmark async
  for _ = 1, iterations do
    collectgarbage("collect")
    local waiter, signal = create_waiter(timeout_ms)
    local start = now_ms()
    local ok, err = pcall(function()
      async_fn(function()
        local elapsed = now_ms() - start
        signal(elapsed)
      end)
    end)
    if ok then
      local elapsed, wait_err = waiter()
      if not wait_err then
        table.insert(async_times, elapsed)
      end
    end
  end

  -- Calculate statistics
  local sync_avg, sync_min, sync_max, sync_stddev = calc_stats(sync_times)
  local async_avg, async_min, async_max, async_stddev = calc_stats(async_times)

  return {
    name = name,
    sync_times = sync_times,
    async_times = async_times,
    sync_avg = sync_avg,
    async_avg = async_avg,
    sync_min = sync_min,
    async_min = async_min,
    sync_max = sync_max,
    async_max = async_max,
    sync_stddev = sync_stddev,
    async_stddev = async_stddev,
    speedup = async_avg > 0 and (sync_avg / async_avg) or 0,
    async_faster = async_avg < sync_avg,
    iterations = iterations,
  }
end

--- Run a single async-only benchmark (no sync comparison)
--- @param name string Benchmark name
--- @param async_fn function Async function (receives callback as last arg)
--- @param opts table? Options
--- @return table result
function M.run_async_only(name, async_fn, opts)
  opts = opts or {}
  local iterations = opts.iterations or 10
  local warmup = opts.warmup or 2
  local timeout_ms = opts.timeout_ms or 30000

  local times = {}

  -- Warmup
  for _ = 1, warmup do
    local waiter, signal = create_waiter(timeout_ms)
    pcall(function()
      async_fn(function() signal(true) end)
    end)
    waiter()
  end

  -- Benchmark
  for _ = 1, iterations do
    collectgarbage("collect")
    local waiter, signal = create_waiter(timeout_ms)
    local start = now_ms()
    local ok = pcall(function()
      async_fn(function()
        local elapsed = now_ms() - start
        signal(elapsed)
      end)
    end)
    if ok then
      local elapsed = waiter()
      if elapsed then
        table.insert(times, elapsed)
      end
    end
  end

  local avg, min_val, max_val, stddev = calc_stats(times)

  return {
    name = name,
    times = times,
    avg = avg,
    min = min_val,
    max = max_val,
    stddev = stddev,
    iterations = iterations,
  }
end

--- Format benchmark result as string
--- @param result BenchmarkResult
--- @return string formatted
function M.format_result(result)
  local lines = {
    string.format("## %s", result.name),
    "",
    string.format("| Metric | Sync | Async |"),
    string.format("|--------|------|-------|"),
    string.format("| Avg (ms) | %.2f | %.2f |", result.sync_avg, result.async_avg),
    string.format("| Min (ms) | %.2f | %.2f |", result.sync_min, result.async_min),
    string.format("| Max (ms) | %.2f | %.2f |", result.sync_max, result.async_max),
    string.format("| Std Dev | %.2f | %.2f |", result.sync_stddev or 0, result.async_stddev or 0),
    "",
    string.format("**Speedup**: %.2fx", result.speedup),
    string.format("**Winner**: %s", result.async_faster and "Async" or "Sync"),
    string.format("**Iterations**: %d", result.iterations),
    "",
  }
  return table.concat(lines, "\n")
end

--- Format async-only result
--- @param result table
--- @return string formatted
function M.format_async_result(result)
  local lines = {
    string.format("## %s", result.name),
    "",
    string.format("| Metric | Value |"),
    string.format("|--------|-------|"),
    string.format("| Avg (ms) | %.2f |", result.avg),
    string.format("| Min (ms) | %.2f |", result.min),
    string.format("| Max (ms) | %.2f |", result.max),
    string.format("| Std Dev | %.2f |", result.stddev or 0),
    string.format("| Iterations | %d |", result.iterations),
    "",
  }
  return table.concat(lines, "\n")
end

--- Run all benchmarks and generate report
--- @param benchmarks table[] Array of benchmark definitions
--- @param opts table? Options
--- @return string report Markdown report
function M.run_all(benchmarks, opts)
  opts = opts or {}
  local results = {}
  local report_lines = {
    "# SSNS Async Performance Benchmarks",
    "",
    string.format("**Date**: %s", os.date("%Y-%m-%d %H:%M:%S")),
    string.format("**Iterations**: %d (warmup: %d)", opts.iterations or 10, opts.warmup or 2),
    "",
    "---",
    "",
  }

  for _, benchmark in ipairs(benchmarks) do
    vim.notify(string.format("Running benchmark: %s", benchmark.name), vim.log.levels.INFO)

    local result
    if benchmark.async_only then
      result = M.run_async_only(benchmark.name, benchmark.async_fn, opts)
      table.insert(report_lines, M.format_async_result(result))
    else
      result = M.run_comparison(benchmark.name, benchmark.sync_fn, benchmark.async_fn, opts)
      table.insert(report_lines, M.format_result(result))
    end
    table.insert(results, result)
  end

  -- Summary
  table.insert(report_lines, "---")
  table.insert(report_lines, "")
  table.insert(report_lines, "## Summary")
  table.insert(report_lines, "")

  local async_wins = 0
  local total_comparisons = 0
  for _, r in ipairs(results) do
    if r.speedup then
      total_comparisons = total_comparisons + 1
      if r.async_faster then
        async_wins = async_wins + 1
      end
    end
  end

  if total_comparisons > 0 then
    table.insert(report_lines, string.format("- **Async faster in**: %d/%d benchmarks", async_wins, total_comparisons))
  end

  return table.concat(report_lines, "\n")
end

--- Save report to file
--- @param report string Report content
--- @param filepath string? Output path (default: stdpath("data")/ssns/benchmark_results.md)
function M.save_report(report, filepath)
  filepath = filepath or (vim.fn.stdpath("data") .. "/ssns/benchmark_results.md")
  local dir = vim.fn.fnamemodify(filepath, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile(vim.split(report, "\n"), filepath)
  vim.notify(string.format("Benchmark report saved to: %s", filepath), vim.log.levels.INFO)
end

return M
