---@class FormatterStats
---Performance statistics tracking for the SQL formatter.
---Provides timing data for profiling and optimization.
local Stats = {}

---@class FormatterTimingData
---@field tokenization_ns number[] Array of tokenization times in nanoseconds
---@field processing_ns number[] Array of token processing times in nanoseconds
---@field output_ns number[] Array of output generation times in nanoseconds
---@field total_ns number[] Array of total format times in nanoseconds
---@field input_sizes number[] Array of input sizes in bytes
---@field token_counts number[] Array of token counts
---@field cache_hits number Number of cache hits
---@field cache_misses number Number of cache misses
---@field format_count number Total number of format calls

---@type FormatterTimingData
local timing_data = {
  tokenization_ns = {},
  processing_ns = {},
  output_ns = {},
  total_ns = {},
  input_sizes = {},
  token_counts = {},
  cache_hits = 0,
  cache_misses = 0,
  format_count = 0,
}

-- Maximum number of samples to keep (rolling window)
local MAX_SAMPLES = 1000

---Record a timing sample
---@param category string The timing category (tokenization, processing, output, total)
---@param duration_ns number Duration in nanoseconds
local function record_sample(category, duration_ns)
  local samples = timing_data[category .. "_ns"]
  if samples then
    table.insert(samples, duration_ns)
    -- Keep only last MAX_SAMPLES
    if #samples > MAX_SAMPLES then
      table.remove(samples, 1)
    end
  end
end

---Record a complete format operation
---@param metrics table {tokenization_ns, processing_ns, output_ns, total_ns, input_size, token_count, cache_hit}
function Stats.record(metrics)
  timing_data.format_count = timing_data.format_count + 1

  if metrics.tokenization_ns then
    record_sample("tokenization", metrics.tokenization_ns)
  end
  if metrics.processing_ns then
    record_sample("processing", metrics.processing_ns)
  end
  if metrics.output_ns then
    record_sample("output", metrics.output_ns)
  end
  if metrics.total_ns then
    record_sample("total", metrics.total_ns)
  end

  if metrics.input_size then
    table.insert(timing_data.input_sizes, metrics.input_size)
    if #timing_data.input_sizes > MAX_SAMPLES then
      table.remove(timing_data.input_sizes, 1)
    end
  end

  if metrics.token_count then
    table.insert(timing_data.token_counts, metrics.token_count)
    if #timing_data.token_counts > MAX_SAMPLES then
      table.remove(timing_data.token_counts, 1)
    end
  end

  if metrics.cache_hit then
    timing_data.cache_hits = timing_data.cache_hits + 1
  else
    timing_data.cache_misses = timing_data.cache_misses + 1
  end
end

---Calculate statistics for an array of samples
---@param samples number[]
---@return table {min, max, avg, median, p95, p99, count}
local function calculate_stats(samples)
  if not samples or #samples == 0 then
    return { min = 0, max = 0, avg = 0, median = 0, p95 = 0, p99 = 0, count = 0 }
  end

  -- Create sorted copy
  local sorted = {}
  for _, v in ipairs(samples) do
    table.insert(sorted, v)
  end
  table.sort(sorted)

  local count = #sorted
  local sum = 0
  for _, v in ipairs(sorted) do
    sum = sum + v
  end

  local min = sorted[1]
  local max = sorted[count]
  local avg = sum / count
  local median = sorted[math.floor(count / 2) + 1] or sorted[1]
  local p95 = sorted[math.floor(count * 0.95) + 1] or sorted[count]
  local p99 = sorted[math.floor(count * 0.99) + 1] or sorted[count]

  return {
    min = min,
    max = max,
    avg = avg,
    median = median,
    p95 = p95,
    p99 = p99,
    count = count,
  }
end

---Convert nanoseconds to milliseconds
---@param ns number Nanoseconds
---@return number Milliseconds
local function ns_to_ms(ns)
  return ns / 1000000
end

---Get comprehensive statistics summary
---@return table
function Stats.get_summary()
  local tokenization = calculate_stats(timing_data.tokenization_ns)
  local processing = calculate_stats(timing_data.processing_ns)
  local output = calculate_stats(timing_data.output_ns)
  local total = calculate_stats(timing_data.total_ns)
  local input_sizes = calculate_stats(timing_data.input_sizes)
  local token_counts = calculate_stats(timing_data.token_counts)

  local cache_total = timing_data.cache_hits + timing_data.cache_misses
  local cache_hit_rate = cache_total > 0 and (timing_data.cache_hits / cache_total * 100) or 0

  return {
    format_count = timing_data.format_count,
    sample_count = total.count,

    -- Timing (in ms)
    tokenization_ms = {
      min = ns_to_ms(tokenization.min),
      max = ns_to_ms(tokenization.max),
      avg = ns_to_ms(tokenization.avg),
      median = ns_to_ms(tokenization.median),
      p95 = ns_to_ms(tokenization.p95),
      p99 = ns_to_ms(tokenization.p99),
    },
    processing_ms = {
      min = ns_to_ms(processing.min),
      max = ns_to_ms(processing.max),
      avg = ns_to_ms(processing.avg),
      median = ns_to_ms(processing.median),
      p95 = ns_to_ms(processing.p95),
      p99 = ns_to_ms(processing.p99),
    },
    output_ms = {
      min = ns_to_ms(output.min),
      max = ns_to_ms(output.max),
      avg = ns_to_ms(output.avg),
      median = ns_to_ms(output.median),
      p95 = ns_to_ms(output.p95),
      p99 = ns_to_ms(output.p99),
    },
    total_ms = {
      min = ns_to_ms(total.min),
      max = ns_to_ms(total.max),
      avg = ns_to_ms(total.avg),
      median = ns_to_ms(total.median),
      p95 = ns_to_ms(total.p95),
      p99 = ns_to_ms(total.p99),
    },

    -- Input characteristics
    input_size = {
      min = input_sizes.min,
      max = input_sizes.max,
      avg = input_sizes.avg,
    },
    token_count = {
      min = token_counts.min,
      max = token_counts.max,
      avg = token_counts.avg,
    },

    -- Cache stats
    cache = {
      hits = timing_data.cache_hits,
      misses = timing_data.cache_misses,
      hit_rate = cache_hit_rate,
    },

    -- Performance ratios
    throughput = {
      bytes_per_ms = input_sizes.avg > 0 and total.avg > 0
          and (input_sizes.avg / ns_to_ms(total.avg))
          or 0,
      tokens_per_ms = token_counts.avg > 0 and total.avg > 0
          and (token_counts.avg / ns_to_ms(total.avg))
          or 0,
    },
  }
end

---Format summary for display
---@return string
function Stats.format_summary()
  local summary = Stats.get_summary()
  local lines = {}

  table.insert(lines, "=== SQL Formatter Performance Stats ===")
  table.insert(lines, "")
  table.insert(lines, string.format("Total format calls: %d", summary.format_count))
  table.insert(lines, string.format("Samples collected:  %d", summary.sample_count))
  table.insert(lines, "")

  if summary.sample_count > 0 then
    table.insert(lines, "Timing (milliseconds):")
    table.insert(lines, string.format("  Tokenization:  avg=%.3f  median=%.3f  p95=%.3f  max=%.3f",
      summary.tokenization_ms.avg, summary.tokenization_ms.median,
      summary.tokenization_ms.p95, summary.tokenization_ms.max))
    table.insert(lines, string.format("  Processing:    avg=%.3f  median=%.3f  p95=%.3f  max=%.3f",
      summary.processing_ms.avg, summary.processing_ms.median,
      summary.processing_ms.p95, summary.processing_ms.max))
    table.insert(lines, string.format("  Output:        avg=%.3f  median=%.3f  p95=%.3f  max=%.3f",
      summary.output_ms.avg, summary.output_ms.median,
      summary.output_ms.p95, summary.output_ms.max))
    table.insert(lines, string.format("  Total:         avg=%.3f  median=%.3f  p95=%.3f  max=%.3f",
      summary.total_ms.avg, summary.total_ms.median,
      summary.total_ms.p95, summary.total_ms.max))
    table.insert(lines, "")

    table.insert(lines, "Input characteristics:")
    table.insert(lines, string.format("  Size (bytes):  min=%d  avg=%.0f  max=%d",
      summary.input_size.min, summary.input_size.avg, summary.input_size.max))
    table.insert(lines, string.format("  Tokens:        min=%d  avg=%.0f  max=%d",
      summary.token_count.min, summary.token_count.avg, summary.token_count.max))
    table.insert(lines, "")

    table.insert(lines, "Cache performance:")
    table.insert(lines, string.format("  Hits: %d  Misses: %d  Hit rate: %.1f%%",
      summary.cache.hits, summary.cache.misses, summary.cache.hit_rate))
    table.insert(lines, "")

    table.insert(lines, "Throughput:")
    table.insert(lines, string.format("  %.1f bytes/ms  %.1f tokens/ms",
      summary.throughput.bytes_per_ms, summary.throughput.tokens_per_ms))
  else
    table.insert(lines, "No timing data collected yet.")
    table.insert(lines, "Format some SQL to start collecting stats.")
  end

  return table.concat(lines, "\n")
end

---Reset all statistics
function Stats.reset()
  timing_data = {
    tokenization_ns = {},
    processing_ns = {},
    output_ns = {},
    total_ns = {},
    input_sizes = {},
    token_counts = {},
    cache_hits = 0,
    cache_misses = 0,
    format_count = 0,
  }
end

---Get raw timing data (for export/analysis)
---@return FormatterTimingData
function Stats.get_raw()
  return vim.deepcopy(timing_data)
end

return Stats
