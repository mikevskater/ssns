---@class FormatterBenchmark
---Benchmark utilities for profiling and testing formatter performance.
---Generates various SQL test cases and measures formatting speed.
local Benchmark = {}

local Stats = require('nvim-ssns.formatter.stats')

---Generate a simple SELECT query with N columns
---@param num_columns number Number of columns
---@param num_tables number Number of tables in FROM clause
---@return string
function Benchmark.generate_simple_select(num_columns, num_tables)
  num_columns = num_columns or 10
  num_tables = num_tables or 1

  local columns = {}
  for i = 1, num_columns do
    table.insert(columns, string.format("col%d", i))
  end

  local tables = {}
  for i = 1, num_tables do
    table.insert(tables, string.format("table%d t%d", i, i))
  end

  return string.format("SELECT %s FROM %s",
    table.concat(columns, ", "),
    table.concat(tables, ", "))
end

---Generate a complex SELECT with JOINs
---@param num_columns number Number of columns per table
---@param num_joins number Number of JOIN clauses
---@return string
function Benchmark.generate_join_query(num_columns, num_joins)
  num_columns = num_columns or 5
  num_joins = num_joins or 3

  local columns = {}
  for t = 0, num_joins do
    local alias = t == 0 and "t" or string.format("j%d", t)
    for c = 1, num_columns do
      table.insert(columns, string.format("%s.col%d", alias, c))
    end
  end

  local joins = {}
  for j = 1, num_joins do
    table.insert(joins, string.format(
      "INNER JOIN table%d j%d ON t.id = j%d.table_id", j, j, j))
  end

  return string.format("SELECT %s FROM main_table t %s",
    table.concat(columns, ", "),
    table.concat(joins, " "))
end

---Generate a query with WHERE conditions
---@param num_conditions number Number of AND conditions
---@return string
function Benchmark.generate_where_query(num_conditions)
  num_conditions = num_conditions or 10

  local conditions = {}
  for i = 1, num_conditions do
    if i % 3 == 0 then
      table.insert(conditions, string.format("col%d IN (1, 2, 3, 4, 5)", i))
    elseif i % 2 == 0 then
      table.insert(conditions, string.format("col%d BETWEEN %d AND %d", i, i, i * 10))
    else
      table.insert(conditions, string.format("col%d = %d", i, i))
    end
  end

  return string.format("SELECT * FROM test_table WHERE %s",
    table.concat(conditions, " AND "))
end

---Generate a query with CTEs
---@param num_ctes number Number of CTEs
---@param columns_per_cte number Columns per CTE
---@return string
function Benchmark.generate_cte_query(num_ctes, columns_per_cte)
  num_ctes = num_ctes or 3
  columns_per_cte = columns_per_cte or 5

  local ctes = {}
  for i = 1, num_ctes do
    local columns = {}
    for c = 1, columns_per_cte do
      table.insert(columns, string.format("col%d", c))
    end
    table.insert(ctes, string.format("cte%d AS (SELECT %s FROM source%d WHERE id > %d)",
      i, table.concat(columns, ", "), i, i * 100))
  end

  return string.format("WITH %s SELECT * FROM cte1",
    table.concat(ctes, ", "))
end

---Generate a query with nested subqueries
---@param depth number Nesting depth
---@return string
function Benchmark.generate_nested_subquery(depth)
  depth = depth or 3

  local function build_subquery(level)
    if level >= depth then
      return "SELECT id, value FROM base_table"
    end
    return string.format("SELECT * FROM (%s) sub%d WHERE sub%d.value > %d",
      build_subquery(level + 1), level, level, level * 10)
  end

  return build_subquery(1)
end

---Generate a query with CASE expressions
---@param num_cases number Number of CASE expressions
---@param when_clauses number WHEN clauses per CASE
---@return string
function Benchmark.generate_case_query(num_cases, when_clauses)
  num_cases = num_cases or 3
  when_clauses = when_clauses or 5

  local cases = {}
  for i = 1, num_cases do
    local whens = {}
    for w = 1, when_clauses do
      table.insert(whens, string.format("WHEN status = %d THEN 'Status%d'", w, w))
    end
    table.insert(cases, string.format("CASE %s ELSE 'Unknown' END AS status_text%d",
      table.concat(whens, " "), i))
  end

  return string.format("SELECT id, %s FROM status_table",
    table.concat(cases, ", "))
end

---Generate a query with window functions
---@param num_windows number Number of window functions
---@return string
function Benchmark.generate_window_query(num_windows)
  num_windows = num_windows or 5

  local windows = {}
  local funcs = { "ROW_NUMBER", "RANK", "DENSE_RANK", "LAG", "LEAD" }

  for i = 1, num_windows do
    local func = funcs[((i - 1) % #funcs) + 1]
    if func == "LAG" or func == "LEAD" then
      table.insert(windows, string.format(
        "%s(value, 1) OVER (PARTITION BY category ORDER BY created_at) AS %s_%d",
        func, func:lower(), i))
    else
      table.insert(windows, string.format(
        "%s() OVER (PARTITION BY category ORDER BY created_at DESC) AS %s_%d",
        func, func:lower(), i))
    end
  end

  return string.format("SELECT id, category, value, %s FROM analytics_data",
    table.concat(windows, ", "))
end

---Generate a complex production-like query
---@param complexity string "small"|"medium"|"large"|"xlarge"
---@return string
function Benchmark.generate_complex_query(complexity)
  complexity = complexity or "medium"

  local configs = {
    small = { cols = 10, joins = 2, conditions = 5, ctes = 0 },
    medium = { cols = 20, joins = 4, conditions = 10, ctes = 2 },
    large = { cols = 40, joins = 8, conditions = 20, ctes = 4 },
    xlarge = { cols = 80, joins = 15, conditions = 40, ctes = 6 },
  }

  local cfg = configs[complexity] or configs.medium

  -- Build CTE section
  local cte_section = ""
  if cfg.ctes > 0 then
    local ctes = {}
    for i = 1, cfg.ctes do
      local cols = {}
      for c = 1, 5 do
        table.insert(cols, string.format("c%d.col%d", i, c))
      end
      table.insert(ctes, string.format(
        "cte%d AS (\n  SELECT %s\n  FROM source_table_%d c%d\n  WHERE c%d.active = 1\n)",
        i, table.concat(cols, ", "), i, i, i))
    end
    cte_section = "WITH " .. table.concat(ctes, ",\n") .. "\n"
  end

  -- Build SELECT columns
  local columns = {}
  for i = 1, cfg.cols do
    if i % 5 == 0 then
      table.insert(columns, string.format("COALESCE(t.col%d, 0) AS col%d", i, i))
    elseif i % 3 == 0 then
      table.insert(columns, string.format("t.col%d", i))
    else
      table.insert(columns, string.format("j%d.col%d", (i % cfg.joins) + 1, i))
    end
  end

  -- Build JOINs
  local joins = {}
  for i = 1, cfg.joins do
    local join_type = i % 2 == 0 and "LEFT" or "INNER"
    table.insert(joins, string.format(
      "%s JOIN related_table_%d j%d\n    ON t.id = j%d.parent_id AND j%d.deleted = 0",
      join_type, i, i, i, i))
  end

  -- Build WHERE conditions
  local conditions = {}
  for i = 1, cfg.conditions do
    if i % 4 == 0 then
      table.insert(conditions, string.format("t.col%d IN (SELECT id FROM lookup_%d)", i, i))
    elseif i % 3 == 0 then
      table.insert(conditions, string.format("t.col%d BETWEEN %d AND %d", i, i, i * 100))
    elseif i % 2 == 0 then
      table.insert(conditions, string.format("t.col%d IS NOT NULL", i))
    else
      table.insert(conditions, string.format("t.col%d = %d", i, i))
    end
  end

  return string.format([[%sSELECT
%s
FROM main_table t
%s
WHERE %s
GROUP BY t.id
HAVING COUNT(*) > 1
ORDER BY t.created_at DESC]],
    cte_section,
    "    " .. table.concat(columns, ",\n    "),
    table.concat(joins, "\n"),
    table.concat(conditions, "\n    AND "))
end

---Generate multiple statements
---@param num_statements number Number of statements
---@param statement_type string|nil Type of statement to generate
---@return string
function Benchmark.generate_batch(num_statements, statement_type)
  num_statements = num_statements or 10
  statement_type = statement_type or "mixed"

  local statements = {}
  local generators = {
    { fn = Benchmark.generate_simple_select, args = { 10, 2 } },
    { fn = Benchmark.generate_join_query, args = { 5, 3 } },
    { fn = Benchmark.generate_where_query, args = { 10 } },
    { fn = Benchmark.generate_case_query, args = { 2, 4 } },
    { fn = Benchmark.generate_window_query, args = { 3 } },
  }

  for i = 1, num_statements do
    local gen
    if statement_type == "mixed" then
      gen = generators[((i - 1) % #generators) + 1]
    elseif statement_type == "select" then
      gen = generators[1]
    elseif statement_type == "join" then
      gen = generators[2]
    elseif statement_type == "where" then
      gen = generators[3]
    else
      gen = generators[1]
    end

    table.insert(statements, gen.fn(table.unpack(gen.args)))
  end

  return table.concat(statements, ";\n\n") .. ";"
end

---Run a benchmark and return results
---@param sql string SQL to format
---@param iterations number Number of iterations
---@param warmup number Warmup iterations (not counted)
---@return table {iterations, total_ms, avg_ms, min_ms, max_ms, input_size, tokens}
function Benchmark.run(sql, iterations, warmup)
  iterations = iterations or 100
  warmup = warmup or 10

  local Engine = require('nvim-ssns.formatter.engine')
  local config = require('nvim-ssns.config').get_formatter()
  local hrtime = vim.loop.hrtime

  -- Warmup runs (not recorded)
  for _ = 1, warmup do
    Engine.format(sql, config)
  end

  -- Timed runs
  local times = {}
  local total = 0

  for _ = 1, iterations do
    local start = hrtime()
    Engine.format(sql, config)
    local elapsed = hrtime() - start
    table.insert(times, elapsed)
    total = total + elapsed
  end

  -- Calculate stats
  table.sort(times)
  local min_ns = times[1]
  local max_ns = times[#times]
  local avg_ns = total / iterations
  local median_ns = times[math.floor(#times / 2) + 1]

  return {
    iterations = iterations,
    total_ms = total / 1000000,
    avg_ms = avg_ns / 1000000,
    min_ms = min_ns / 1000000,
    max_ms = max_ns / 1000000,
    median_ms = median_ns / 1000000,
    input_size = #sql,
    input_lines = select(2, sql:gsub("\n", "\n")) + 1,
  }
end

---Run a suite of benchmarks
---@param opts table|nil {iterations?: number, warmup?: number, sizes?: string[]}
---@return table[] Array of benchmark results
function Benchmark.run_suite(opts)
  opts = opts or {}
  local iterations = opts.iterations or 50
  local warmup = opts.warmup or 5
  local sizes = opts.sizes or { "small", "medium", "large" }

  local results = {}

  -- Test different query types
  local test_cases = {
    { name = "Simple SELECT (20 cols)", sql = Benchmark.generate_simple_select(20, 3) },
    { name = "JOIN query (5 joins)", sql = Benchmark.generate_join_query(5, 5) },
    { name = "WHERE conditions (20)", sql = Benchmark.generate_where_query(20) },
    { name = "CTEs (4 CTEs)", sql = Benchmark.generate_cte_query(4, 5) },
    { name = "Nested subquery (5 deep)", sql = Benchmark.generate_nested_subquery(5) },
    { name = "CASE expressions (5)", sql = Benchmark.generate_case_query(5, 5) },
    { name = "Window functions (8)", sql = Benchmark.generate_window_query(8) },
  }

  -- Add complexity tests
  for _, size in ipairs(sizes) do
    table.insert(test_cases, {
      name = string.format("Complex (%s)", size),
      sql = Benchmark.generate_complex_query(size)
    })
  end

  -- Add batch tests
  table.insert(test_cases, {
    name = "Batch (10 statements)",
    sql = Benchmark.generate_batch(10, "mixed")
  })
  table.insert(test_cases, {
    name = "Batch (50 statements)",
    sql = Benchmark.generate_batch(50, "mixed")
  })

  -- Run each test
  for _, test in ipairs(test_cases) do
    local result = Benchmark.run(test.sql, iterations, warmup)
    result.name = test.name
    table.insert(results, result)
  end

  return results
end

---Format benchmark results for display
---@param results table[] Benchmark results
---@return string
function Benchmark.format_results(results)
  local lines = {}

  table.insert(lines, "=== SQL Formatter Benchmark Results ===")
  table.insert(lines, "")
  table.insert(lines, string.format("%-30s %8s %8s %8s %8s %8s %8s",
    "Test Case", "Size", "Lines", "Avg(ms)", "Med(ms)", "Min(ms)", "Max(ms)"))
  table.insert(lines, string.rep("-", 90))

  for _, r in ipairs(results) do
    table.insert(lines, string.format("%-30s %8d %8d %8.3f %8.3f %8.3f %8.3f",
      r.name, r.input_size, r.input_lines or 0,
      r.avg_ms, r.median_ms, r.min_ms, r.max_ms))
  end

  table.insert(lines, string.rep("-", 90))

  -- Summary stats
  local total_avg = 0
  local max_time = 0
  for _, r in ipairs(results) do
    total_avg = total_avg + r.avg_ms
    if r.max_ms > max_time then max_time = r.max_ms end
  end

  table.insert(lines, "")
  table.insert(lines, string.format("Average across all tests: %.3f ms", total_avg / #results))
  table.insert(lines, string.format("Maximum single run: %.3f ms", max_time))

  return table.concat(lines, "\n")
end

---Run benchmarks and display results
---@param opts table|nil Benchmark options
function Benchmark.run_and_display(opts)
  vim.notify("Running formatter benchmarks...", vim.log.levels.INFO)

  local results = Benchmark.run_suite(opts)
  
  local UiFloat = require('nvim-float.window')
  local ContentBuilder = require('nvim-float.content')
  
  local cb = ContentBuilder.new()
  
  cb:header("SQL Formatter Benchmark Results")
  cb:separator("=", 90)
  cb:blank()
  
  -- Header row
  cb:spans({
    { text = string.format("%-30s", "Test Case"), style = "label" },
    { text = string.format(" %8s", "Size"), style = "label" },
    { text = string.format(" %8s", "Lines"), style = "label" },
    { text = string.format(" %8s", "Avg(ms)"), style = "label" },
    { text = string.format(" %8s", "Med(ms)"), style = "label" },
    { text = string.format(" %8s", "Min(ms)"), style = "label" },
    { text = string.format(" %8s", "Max(ms)"), style = "label" },
  })
  cb:separator("-", 90)

  for _, r in ipairs(results) do
    -- Color-code avg time based on performance
    local avg_style = r.avg_ms < 10 and "success" or (r.avg_ms < 50 and "warning" or "error")
    cb:spans({
      { text = string.format("%-30s", r.name) },
      { text = string.format(" %8d", r.input_size), style = "number" },
      { text = string.format(" %8d", r.input_lines or 0), style = "number" },
      { text = string.format(" %8.3f", r.avg_ms), style = avg_style },
      { text = string.format(" %8.3f", r.median_ms), style = "number" },
      { text = string.format(" %8.3f", r.min_ms), style = "success" },
      { text = string.format(" %8.3f", r.max_ms), style = "muted" },
    })
  end

  cb:separator("-", 90)
  cb:blank()

  -- Summary stats
  local total_avg = 0
  local max_time = 0
  for _, r in ipairs(results) do
    total_avg = total_avg + r.avg_ms
    if r.max_ms > max_time then max_time = r.max_ms end
  end

  cb:spans({
    { text = "Average across all tests: ", style = "label" },
    { text = string.format("%.3f ms", total_avg / #results), style = "number" },
  })
  cb:spans({
    { text = "Maximum single run: ", style = "label" },
    { text = string.format("%.3f ms", max_time), style = "number" },
  })

  UiFloat.create_styled(cb, {
    title = "Formatter Benchmarks",
    min_width = 95,
    max_height = 30,
    footer = "q/Esc: close",
  })

  vim.notify("Benchmark complete. Press 'q' or <Esc> to close.", vim.log.levels.INFO)
end

return Benchmark
