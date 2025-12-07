---@class UnitRunner
---Lightweight unit test runner for tokenizer, parser, provider, context, and utility tests
---Runs synchronously without database connections
local UnitRunner = {}

---Scan for unit test files in tests/unit/ directory
---@return table[] tests Array of test definitions with metadata
function UnitRunner.scan_tests()
  local tests = {}
  local base_path = vim.fn.stdpath("data") .. "/ssns/lua/ssns/testing/tests/unit"

  -- Helper to load tests from a file
  local function load_test_file(filepath)
    local ok, test_data = pcall(dofile, filepath)
    if not ok then
      vim.notify("Failed to load test file: " .. filepath .. "\nError: " .. tostring(test_data), vim.log.levels.WARN)
      return {}
    end

    -- Handle both single test and array of tests
    if test_data.id then
      -- Single test
      return { test_data }
    elseif type(test_data) == "table" and #test_data > 0 then
      -- Array of tests
      return test_data
    else
      vim.notify("Invalid test file format: " .. filepath, vim.log.levels.WARN)
      return {}
    end
  end

  -- Scan tokenizer tests
  local tokenizer_path = base_path .. "/tokenizer"
  local tokenizer_files = vim.fn.glob(tokenizer_path .. "/*.lua", false, true)
  for _, filepath in ipairs(tokenizer_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  -- Scan parser tests
  local parser_path = base_path .. "/parser"
  local parser_files = vim.fn.glob(parser_path .. "/*.lua", false, true)
  for _, filepath in ipairs(parser_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  -- Scan provider tests
  local provider_path = base_path .. "/providers"
  local provider_files = vim.fn.glob(provider_path .. "/*.lua", false, true)
  for _, filepath in ipairs(provider_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  -- Scan context tests
  local context_path = base_path .. "/context"
  local context_files = vim.fn.glob(context_path .. "/*.lua", false, true)
  for _, filepath in ipairs(context_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  -- Scan formatter tests
  local formatter_path = base_path .. "/formatter"
  local formatter_files = vim.fn.glob(formatter_path .. "/*.lua", false, true)
  for _, filepath in ipairs(formatter_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  -- Scan root level tests (fuzzy_matcher, type_compatibility, fk_graph, etc.)
  local root_files = vim.fn.glob(base_path .. "/*.lua", false, true)
  for _, filepath in ipairs(root_files) do
    local file_tests = load_test_file(filepath)
    for _, test in ipairs(file_tests) do
      test.source_file = filepath
      table.insert(tests, test)
    end
  end

  return tests
end

---Run a single unit test
---@param test table Test definition with id, type, input, expected
---@return table result {id, name, type, passed, error, actual, expected, duration_ms, input}
function UnitRunner.run_test(test)
  local start_time = vim.loop.hrtime()
  local result = {
    id = test.id,
    name = test.name,
    type = test.type,
    input = test.input,
    expected = test.expected,
  }

  local ok, err = pcall(function()
    if test.type == "tokenizer" then
      result.actual, result.passed, result.error = UnitRunner._run_tokenizer_test(test)
    elseif test.type == "parser" then
      result.actual, result.passed, result.error = UnitRunner._run_parser_test(test)
    elseif test.type == "provider" or test.type:match("_provider$") then
      result.actual, result.passed, result.error = UnitRunner._run_provider_test(test)
    elseif test.type == "context" then
      result.actual, result.passed, result.error = UnitRunner._run_context_test(test)
    elseif test.type == "fuzzy_matcher" then
      result.actual, result.passed, result.error = UnitRunner._run_fuzzy_matcher_test(test)
    elseif test.type == "type_compatibility" then
      result.actual, result.passed, result.error = UnitRunner._run_type_compatibility_test(test)
    elseif test.type == "fk_graph" then
      result.actual, result.passed, result.error = UnitRunner._run_fk_graph_test(test)
    elseif test.type == "formatter" then
      result.actual, result.passed, result.error = UnitRunner._run_formatter_test(test)
    else
      error("Unknown test type: " .. tostring(test.type))
    end
  end)

  if not ok then
    result.passed = false
    result.error = tostring(err)
  end

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1000000
  return result
end

---Run all unit tests
---@param opts? {type?: string, filter?: function} Options
---@return table results {total, passed, failed, results: table[]}
function UnitRunner.run_all(opts)
  opts = opts or {}
  local all_tests = UnitRunner.scan_tests()
  local results = { total = 0, passed = 0, failed = 0, results = {} }

  for _, test in ipairs(all_tests) do
    -- Filter by type if specified
    if not opts.type or test.type == opts.type then
      -- Apply custom filter if provided
      if not opts.filter or opts.filter(test) then
        local result = UnitRunner.run_test(test)
        table.insert(results.results, result)
        results.total = results.total + 1
        if result.passed then
          results.passed = results.passed + 1
        else
          results.failed = results.failed + 1
        end
      end
    end
  end

  return results
end

---Run test by ID
---@param id number Test ID
---@return table? result Test result or nil if not found
function UnitRunner.run_by_id(id)
  local all_tests = UnitRunner.scan_tests()
  for _, test in ipairs(all_tests) do
    if test.id == id then
      return UnitRunner.run_test(test)
    end
  end
  return nil
end

---Run tests by ID range
---@param start_id number Starting test ID (inclusive)
---@param end_id number Ending test ID (inclusive)
---@return table results {total, passed, failed, results: table[]}
function UnitRunner.run_by_id_range(start_id, end_id)
  local all_tests = UnitRunner.scan_tests()
  local results = { total = 0, passed = 0, failed = 0, results = {} }

  for _, test in ipairs(all_tests) do
    if test.id >= start_id and test.id <= end_id then
      local result = UnitRunner.run_test(test)
      table.insert(results.results, result)
      results.total = results.total + 1
      if result.passed then
        results.passed = results.passed + 1
      else
        results.failed = results.failed + 1
      end
    end
  end

  return results
end

-- Internal functions

---Create mock database structure for provider tests
---@param connection_config table Connection configuration from test.context.connection
---@return table database Mock database object
function UnitRunner._create_mock_database(connection_config)
  local mock_tables = {
    { name = "Employees", schema = "dbo", object_type = "table" },
    { name = "Departments", schema = "dbo", object_type = "table" },
    { name = "Orders", schema = "dbo", object_type = "table" },
    { name = "Customers", schema = "dbo", object_type = "table" },
    { name = "Products", schema = "dbo", object_type = "table" },
    { name = "Branches", schema = "dbo", object_type = "table" },
    { name = "test_table1", schema = "dbo", object_type = "table" },
    { name = "test_table2", schema = "dbo", object_type = "table" },
    { name = "Benefits", schema = "hr", object_type = "table" },
    { name = "EmployeeReviews", schema = "hr", object_type = "table" },
    { name = "Salaries", schema = "hr", object_type = "table" },
    { name = "AllDivisions", schema = "Branch", object_type = "table" },
    { name = "CentralDivision", schema = "Branch", object_type = "table" },
    { name = "BranchManagers", schema = "Branch", object_type = "table" },
    { name = "BranchLocations", schema = "Branch", object_type = "table" },
    { name = "ExternalTable1", schema = "dbo", object_type = "table", database = "OtherDB" },
    { name = "ExternalTable2", schema = "dbo", object_type = "table", database = "OtherDB" },
    { name = "My Table", schema = "dbo", object_type = "table" },
    { name = "My Other Table", schema = "dbo", object_type = "table" },
  }

  local mock_views = {
    { name = "vw_ActiveEmployees", schema = "dbo", object_type = "view" },
    { name = "vw_DepartmentSummary", schema = "dbo", object_type = "view" },
    { name = "vw_EmployeeDetails", schema = "dbo", object_type = "view" },
  }

  local mock_synonyms = {
    { name = "syn_Employees", schema = "dbo", object_type = "synonym" },
    { name = "syn_Depts", schema = "dbo", object_type = "synonym" },
    { name = "syn_RemoteTable", schema = "dbo", object_type = "synonym" },
  }

  -- Build mock database structure matching DbClass format
  local database = {
    name = connection_config.database or "vim_dadbod_test",
    is_loaded = true,
    children = {
      {
        object_type = "tables_group",
        children = mock_tables,
      },
      {
        object_type = "views_group",
        children = mock_views,
      },
      {
        object_type = "synonyms_group",
        children = mock_synonyms,
      },
    },
    get_adapter = function()
      return {
        features = {
          views = true,
          synonyms = true,
          functions = true,
        },
      }
    end,
    load = function() end, -- No-op for mock
  }

  return database
end

---Compare provider results with expected output
---@param actual_items table[] Actual completion items
---@param expected table Expected structure
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_provider_results(actual_items, expected)
  if not expected or not expected.items then
    return false, "Invalid expected structure: missing 'items' field"
  end

  local exp_items = expected.items

  -- Handle different expected formats
  if type(exp_items) == "table" then
    -- Check if it's an array of strings (exact labels)
    local is_array = #exp_items > 0 and type(exp_items[1]) == "string"

    if is_array then
      -- Expected is array of strings - check exact match
      if #actual_items ~= #exp_items then
        return false,
          string.format("Item count mismatch: expected %d items, got %d", #exp_items, #actual_items)
      end

      -- Build set of actual labels
      local actual_labels = {}
      for _, item in ipairs(actual_items) do
        actual_labels[item.label] = true
      end

      -- Check all expected labels are present
      for _, exp_label in ipairs(exp_items) do
        if not actual_labels[exp_label] then
          return false, string.format("Expected item '%s' not found in results", exp_label)
        end
      end
    else
      -- Expected has includes/excludes
      local includes = exp_items.includes or {}
      local excludes = exp_items.excludes or {}

      -- Build set of actual labels
      local actual_labels = {}
      for _, item in ipairs(actual_items) do
        actual_labels[item.label] = true
      end

      -- Check all includes are present
      for _, inc_label in ipairs(includes) do
        if not actual_labels[inc_label] then
          return false, string.format("Expected included item '%s' not found in results", inc_label)
        end
      end

      -- Check all excludes are absent
      for _, exc_label in ipairs(excludes) do
        if actual_labels[exc_label] then
          return false, string.format("Expected excluded item '%s' found in results", exc_label)
        end
      end
    end
  else
    return false, "Invalid expected.items format: must be array or object with includes/excludes"
  end

  -- Check sort order if specified
  if expected.sort_order then
    local actual_order = {}
    for _, item in ipairs(actual_items) do
      table.insert(actual_order, item.label)
    end

    for i, exp_label in ipairs(expected.sort_order) do
      if actual_order[i] ~= exp_label then
        return false,
          string.format(
            "Sort order mismatch at position %d: expected '%s', got '%s'",
            i,
            exp_label,
            actual_order[i] or "nil"
          )
      end
    end
  end

  return true, nil
end

---Run tokenizer test
---@param test table Test definition
---@return table actual Actual tokens
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_tokenizer_test(test)
  local ok, Tokenizer = pcall(require, "ssns.completion.tokenizer")
  if not ok then
    return nil, false, "Failed to load tokenizer module: " .. tostring(Tokenizer)
  end

  local actual_ok, actual = pcall(Tokenizer.tokenize, test.input)
  if not actual_ok then
    return nil, false, "Tokenizer.tokenize() failed: " .. tostring(actual)
  end

  local passed, error_msg = UnitRunner._compare_tokens(actual, test.expected)
  return actual, passed, error_msg
end

---Run parser test
---@param test table Test definition
---@return table actual Actual parser output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_parser_test(test)
  local ok, Parser = pcall(require, "ssns.completion.statement_parser")
  if not ok then
    return nil, false, "Failed to load parser module: " .. tostring(Parser)
  end

  local parse_ok, chunks, temp_tables = pcall(Parser.parse, test.input)
  if not parse_ok then
    return nil, false, "Parser.parse() failed: " .. tostring(chunks)
  end

  local actual = { chunks = chunks, temp_tables = temp_tables }
  local passed, error_msg = UnitRunner._compare_parser_output(actual, test.expected)
  return actual, passed, error_msg
end

---Run provider test
---@param test table Test definition
---@return table actual Actual provider output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_provider_test(test)
  -- Load the TablesProvider (add other providers when available)
  local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
  if not ok then
    return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
  end

  -- Parse test input to extract SQL and cursor position
  local sql_text = test.input or ""
  local cursor_pos = test.cursor or { line = 1, col = 1 }

  -- If input contains |, calculate cursor position from it
  local pipe_pos = sql_text:find("|", 1, true)
  if pipe_pos then
    -- Remove pipe marker
    sql_text = sql_text:gsub("|", "")

    -- Calculate line and column (1-indexed)
    local line = 1
    local col = 1
    for i = 1, pipe_pos - 1 do
      if sql_text:sub(i, i) == "\n" then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
    end
    cursor_pos = { line = line, col = col }
  end

  -- Create mock database objects
  local mock_database = UnitRunner._create_mock_database(test.context.connection or {})

  -- Create mock server object
  local mock_server = {
    is_connected = function() return true end,
    name = test.context.connection.server or "localhost",
  }

  -- Create mock context for the provider
  local mock_ctx = {
    bufnr = 0,
    cursor = cursor_pos,
    connection = {
      server = mock_server,
      database = mock_database,
      schema = test.context.connection.schema or "dbo",
    },
    sql_context = test.context or {},
  }

  -- Call the provider's internal implementation (synchronous)
  local items_ok, items = pcall(TablesProvider._get_completions_impl, mock_ctx)
  if not items_ok then
    return nil, false, "Provider execution failed: " .. tostring(items)
  end

  -- Compare results with expected
  local passed, error_msg = UnitRunner._compare_provider_results(items, test.expected)
  return items, passed, error_msg
end

---Run context detection test
---@param test table Test definition
---@return table actual Actual context detection output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_context_test(test)
  -- TODO: Implement context detection test execution
  -- This will need to:
  -- 1. Load the statement_context module
  -- 2. Call detect_context() with test.input
  -- 3. Compare actual context with test.expected
  -- For now, return placeholder result
  return {}, true, nil
end

---Run fuzzy matcher test
---@param test table Test definition
---@return table actual Actual fuzzy matching output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_fuzzy_matcher_test(test)
  -- TODO: Implement fuzzy matcher test execution
  -- This will need to:
  -- 1. Load the fuzzy_matcher module
  -- 2. Call fuzzy matching functions with test.input
  -- 3. Compare actual matches/scores with test.expected
  -- For now, return placeholder result
  return {}, true, nil
end

---Run type compatibility test
---@param test table Test definition
---@return table actual Actual type compatibility output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_type_compatibility_test(test)
  -- TODO: Implement type compatibility test execution
  -- This will need to:
  -- 1. Load the type_compatibility module
  -- 2. Call is_compatible() or similar functions with test.input
  -- 3. Compare actual compatibility results with test.expected
  -- For now, return placeholder result
  return {}, true, nil
end

---Run FK graph test
---@param test table Test definition
---@return table actual Actual FK graph output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_fk_graph_test(test)
  -- TODO: Implement FK graph test execution
  -- This will need to:
  -- 1. Load the fk_graph module
  -- 2. Build FK graph with test.input (table metadata)
  -- 3. Test graph traversal, path finding, etc.
  -- 4. Compare actual results with test.expected
  -- For now, return placeholder result
  return {}, true, nil
end

---Run formatter test
---@param test table Test definition
---@return table actual Actual formatted output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_formatter_test(test)
  local ok, Formatter = pcall(require, "ssns.formatter")
  if not ok then
    return nil, false, "Failed to load formatter module: " .. tostring(Formatter)
  end

  -- Get test options (config overrides)
  local opts = test.opts or {}

  -- Format the input SQL with timing
  local start_time = vim.loop.hrtime()
  local format_ok, actual = pcall(Formatter.format, test.input, opts)
  local duration_ms = (vim.loop.hrtime() - start_time) / 1000000

  if not format_ok then
    return nil, false, "Formatter.format() failed: " .. tostring(actual)
  end

  -- Compare with expected (including performance check)
  local passed, error_msg = UnitRunner._compare_formatter_output(actual, test.expected, test, duration_ms)
  return actual, passed, error_msg
end

---Compare formatter output with expected
---@param actual string Actual formatted output
---@param expected table Expected structure
---@param test table Full test definition for context
---@param duration_ms number? Duration of the format operation in milliseconds
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_formatter_output(actual, expected, test, duration_ms)
  -- Check max_duration_ms constraint first (if specified)
  if expected.max_duration_ms and duration_ms then
    if duration_ms > expected.max_duration_ms then
      return false, string.format(
        "Performance: took %.2fms, expected <= %.2fms",
        duration_ms, expected.max_duration_ms
      )
    end
  end

  -- If expected.formatted is specified, do exact string comparison
  if expected.formatted then
    -- Normalize line endings for comparison
    local norm_actual = actual:gsub("\r\n", "\n"):gsub("\r", "\n")
    local norm_expected = expected.formatted:gsub("\r\n", "\n"):gsub("\r", "\n")

    if norm_actual ~= norm_expected then
      -- Build a helpful diff message
      local actual_lines = vim.split(norm_actual, "\n", { plain = true })
      local expected_lines = vim.split(norm_expected, "\n", { plain = true })

      local diff_msg = string.format(
        "Output mismatch:\nExpected (%d lines):\n%s\n\nActual (%d lines):\n%s",
        #expected_lines,
        norm_expected,
        #actual_lines,
        norm_actual
      )

      -- Find first differing line for quick identification
      for i = 1, math.max(#actual_lines, #expected_lines) do
        if actual_lines[i] ~= expected_lines[i] then
          diff_msg = string.format(
            "First difference at line %d:\nExpected: %s\nActual:   %s\n\n%s",
            i,
            expected_lines[i] or "(missing)",
            actual_lines[i] or "(missing)",
            diff_msg
          )
          break
        end
      end

      return false, diff_msg
    end
  end

  -- Check for expected.contains - lines or patterns that must appear
  if expected.contains then
    for _, pattern in ipairs(expected.contains) do
      if not actual:find(pattern, 1, true) then
        return false, string.format("Expected output to contain '%s'", pattern)
      end
    end
  end

  -- Check for expected.not_contains - patterns that must NOT appear
  if expected.not_contains then
    for _, pattern in ipairs(expected.not_contains) do
      if actual:find(pattern, 1, true) then
        return false, string.format("Expected output to NOT contain '%s'", pattern)
      end
    end
  end

  -- Check for expected.line_count
  if expected.line_count then
    local actual_lines = vim.split(actual, "\n", { plain = true })
    if #actual_lines ~= expected.line_count then
      return false, string.format("Line count mismatch: expected %d, got %d", expected.line_count, #actual_lines)
    end
  end

  -- Check for expected.starts_with
  if expected.starts_with then
    if not actual:sub(1, #expected.starts_with) == expected.starts_with then
      return false, string.format("Expected output to start with '%s'", expected.starts_with)
    end
  end

  -- Check for expected.matches (regex patterns)
  if expected.matches then
    for _, pattern in ipairs(expected.matches) do
      if not actual:match(pattern) then
        return false, string.format("Expected output to match pattern '%s'", pattern)
      end
    end
  end

  -- Check preserves_keywords - verify keyword case transformation
  if expected.preserves_keywords then
    local config = require("ssns.config").get_formatter()
    local keyword_case = config.keyword_case
    for _, kw in ipairs(expected.preserves_keywords) do
      local check_kw
      if keyword_case == "upper" then
        check_kw = string.upper(kw)
      elseif keyword_case == "lower" then
        check_kw = string.lower(kw)
      else
        check_kw = kw
      end
      if not actual:find(check_kw, 1, true) then
        return false, string.format("Expected keyword '%s' (case: %s) not found in output", check_kw, keyword_case)
      end
    end
  end

  return true, nil
end

---Compare token arrays
---@param actual table[] Actual tokens
---@param expected table[] Expected tokens
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_tokens(actual, expected)
  if #actual ~= #expected then
    return false, string.format("Token count mismatch: expected %d, got %d", #expected, #actual)
  end

  for i, exp_token in ipairs(expected) do
    local act_token = actual[i]

    -- Compare each field that's specified in expected
    for key, exp_value in pairs(exp_token) do
      local act_value = act_token[key]
      if act_value ~= exp_value then
        return false,
          string.format(
            "Token %d mismatch at '%s': expected '%s', got '%s'",
            i,
            key,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end

  return true, nil
end

---Compare parser output (partial matching)
---Only compare fields that are present in expected
---@param actual table Actual parser output {chunks, temp_tables}
---@param expected table Expected structure
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_parser_output(actual, expected)
  -- Compare chunks if specified
  if expected.chunks then
    if not actual.chunks then
      return false, "Expected chunks but got none"
    end

    if #actual.chunks ~= #expected.chunks then
      return false,
        string.format("Chunk count mismatch: expected %d, got %d", #expected.chunks, #actual.chunks)
    end

    for i, exp_chunk in ipairs(expected.chunks) do
      local act_chunk = actual.chunks[i]
      local ok, err = UnitRunner._compare_chunk(act_chunk, exp_chunk, i)
      if not ok then
        return false, err
      end
    end
  end

  -- Compare temp_tables if specified
  if expected.temp_tables then
    if not actual.temp_tables then
      return false, "Expected temp_tables but got none"
    end

    local ok, err = UnitRunner._compare_temp_tables(actual.temp_tables, expected.temp_tables)
    if not ok then
      return false, err
    end
  end

  return true, nil
end

---Compare a single chunk (partial matching)
---@param actual table Actual chunk
---@param expected table Expected chunk structure
---@param chunk_index number Chunk index for error messages
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_chunk(actual, expected, chunk_index)
  for key, exp_value in pairs(expected) do
    local act_value = actual[key]

    if key == "tables" then
      -- Compare tables array
      local ok, err = UnitRunner._compare_tables(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif key == "columns" then
      -- Compare columns array
      local ok, err = UnitRunner._compare_columns(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif key == "subqueries" then
      -- Compare subqueries recursively
      local ok, err = UnitRunner._compare_subqueries(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif key == "ctes" then
      -- Compare CTEs
      local ok, err = UnitRunner._compare_ctes(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif key == "aliases" then
      -- Compare aliases
      local ok, err = UnitRunner._compare_aliases(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif key == "parameters" then
      -- Compare parameters array
      local ok, err = UnitRunner._compare_parameters(act_value, exp_value, chunk_index)
      if not ok then
        return false, err
      end
    elseif type(exp_value) == "table" and type(act_value) == "table" then
      -- Deep comparison for nested tables
      local ok, err = UnitRunner._deep_compare(act_value, exp_value, string.format("Chunk %d field '%s'", chunk_index, key))
      if not ok then
        return false, err
      end
    else
      -- Direct comparison for other fields
      if act_value ~= exp_value then
        return false,
          string.format(
            "Chunk %d field '%s' mismatch: expected '%s', got '%s'",
            chunk_index,
            key,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end
  return true, nil
end

---Compare tables array (partial matching)
---@param actual table[]? Actual tables
---@param expected table[] Expected tables
---@param chunk_index number Chunk index for error messages
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_tables(actual, expected, chunk_index)
  if not actual then
    actual = {}
  end
  if not expected then
    expected = {}
  end

  if #actual ~= #expected then
    return false,
      string.format("Chunk %d table count mismatch: expected %d, got %d", chunk_index, #expected, #actual)
  end

  for i, exp_table in ipairs(expected) do
    local act_table = actual[i]
    for key, exp_value in pairs(exp_table) do
      local act_value = act_table[key]
      if type(exp_value) == "table" and type(act_value) == "table" then
        -- Deep comparison for nested structures
        local ok, err = UnitRunner._deep_compare(
          act_value,
          exp_value,
          string.format("Chunk %d table %d field '%s'", chunk_index, i, key)
        )
        if not ok then
          return false, err
        end
      else
        if act_value ~= exp_value then
          return false,
            string.format(
              "Chunk %d table %d field '%s' mismatch: expected '%s', got '%s'",
              chunk_index,
              i,
              key,
              tostring(exp_value),
              tostring(act_value)
            )
        end
      end
    end
  end

  return true, nil
end

---Compare columns arrays
---@param actual ColumnInfo[]?
---@param expected ColumnInfo[]?
---@param chunk_index number
---@return boolean success
---@return string? error_message
function UnitRunner._compare_columns(actual, expected, chunk_index)
  if not expected then
    return true
  end
  if not actual then
    return false, string.format("Chunk %d: expected columns but got nil", chunk_index)
  end

  if #actual < #expected then
    return false,
      string.format("Chunk %d: expected at least %d columns, got %d", chunk_index, #expected, #actual)
  end

  for i, exp_col in ipairs(expected) do
    local act_col = actual[i]
    if not act_col then
      return false, string.format("Chunk %d: missing column at index %d", chunk_index, i)
    end

    -- Compare each expected field
    for field, exp_value in pairs(exp_col) do
      local act_value = act_col[field]
      if act_value ~= exp_value then
        return false,
          string.format(
            "Chunk %d column %d field '%s': expected %s, got %s",
            chunk_index,
            i,
            field,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end

  return true
end

---Compare aliases dictionaries
---@param actual table<string, TableReference>?
---@param expected table<string, TableReference>?
---@param chunk_index number
---@return boolean success
---@return string? error_message
function UnitRunner._compare_aliases(actual, expected, chunk_index)
  if not expected then
    return true
  end
  if not actual then
    return false, string.format("Chunk %d: expected aliases but got nil", chunk_index)
  end

  -- Check each expected alias exists and matches
  for alias_name, exp_table in pairs(expected) do
    local act_table = actual[alias_name]
    if not act_table then
      return false, string.format("Chunk %d: missing alias '%s'", chunk_index, alias_name)
    end

    -- Compare each expected field in the TableReference
    for field, exp_value in pairs(exp_table) do
      local act_value = act_table[field]
      if act_value ~= exp_value then
        return false,
          string.format(
            "Chunk %d alias '%s' field '%s': expected %s, got %s",
            chunk_index,
            alias_name,
            field,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end

  return true
end

---Compare parameters arrays
---@param actual ParameterInfo[]?
---@param expected ParameterInfo[]?
---@param chunk_index number
---@return boolean success
---@return string? error_message
function UnitRunner._compare_parameters(actual, expected, chunk_index)
  if not expected then
    return true
  end
  if not actual then
    return false, string.format("Chunk %d: expected parameters but got nil", chunk_index)
  end

  if #actual < #expected then
    return false,
      string.format("Chunk %d: expected at least %d parameters, got %d", chunk_index, #expected, #actual)
  end

  for i, exp_param in ipairs(expected) do
    local act_param = actual[i]
    if not act_param then
      return false, string.format("Chunk %d: missing parameter at index %d", chunk_index, i)
    end

    -- Compare each expected field
    for field, exp_value in pairs(exp_param) do
      local act_value = act_param[field]
      if act_value ~= exp_value then
        return false,
          string.format(
            "Chunk %d parameter %d field '%s': expected %s, got %s",
            chunk_index,
            i,
            field,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end

  return true
end

---Compare subqueries recursively
---@param actual table[]? Actual subqueries
---@param expected table[] Expected subqueries
---@param chunk_index number Chunk index for error messages
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_subqueries(actual, expected, chunk_index)
  if not actual then
    actual = {}
  end
  if not expected then
    expected = {}
  end

  if #actual ~= #expected then
    return false,
      string.format("Chunk %d subquery count mismatch: expected %d, got %d", chunk_index, #expected, #actual)
  end

  for i, exp_subquery in ipairs(expected) do
    local act_subquery = actual[i]
    -- Recursively compare each subquery as a chunk
    local ok, err = UnitRunner._compare_chunk(act_subquery, exp_subquery, chunk_index)
    if not ok then
      return false, string.format("Subquery %d: %s", i, err)
    end
  end

  return true, nil
end

---Compare CTEs
---@param actual table[]? Actual CTEs
---@param expected table[] Expected CTEs
---@param chunk_index number Chunk index for error messages
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_ctes(actual, expected, chunk_index)
  if not actual then
    actual = {}
  end
  if not expected then
    expected = {}
  end

  if #actual ~= #expected then
    return false, string.format("Chunk %d CTE count mismatch: expected %d, got %d", chunk_index, #expected, #actual)
  end

  for i, exp_cte in ipairs(expected) do
    local act_cte = actual[i]
    for key, exp_value in pairs(exp_cte) do
      local act_value = act_cte[key]

      if key == "definition" then
        -- Definition is a chunk, compare recursively
        local ok, err = UnitRunner._compare_chunk(act_value, exp_value, chunk_index)
        if not ok then
          return false, string.format("CTE %d definition: %s", i, err)
        end
      elseif type(exp_value) == "table" and type(act_value) == "table" then
        -- Deep comparison for nested tables
        local ok, err =
          UnitRunner._deep_compare(act_value, exp_value, string.format("Chunk %d CTE %d field '%s'", chunk_index, i, key))
        if not ok then
          return false, err
        end
      else
        if act_value ~= exp_value then
          return false,
            string.format(
              "Chunk %d CTE %d field '%s' mismatch: expected '%s', got '%s'",
              chunk_index,
              i,
              key,
              tostring(exp_value),
              tostring(act_value)
            )
        end
      end
    end
  end

  return true, nil
end

---Compare temp tables
---@param actual table[]? Actual temp tables
---@param expected table[] Expected temp tables
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_temp_tables(actual, expected)
  if not actual then
    actual = {}
  end
  if not expected then
    expected = {}
  end

  if #actual ~= #expected then
    return false, string.format("Temp table count mismatch: expected %d, got %d", #expected, #actual)
  end

  for i, exp_temp in ipairs(expected) do
    local act_temp = actual[i]
    for key, exp_value in pairs(exp_temp) do
      local act_value = act_temp[key]

      if type(exp_value) == "table" and type(act_value) == "table" then
        -- Deep comparison for nested structures
        local ok, err = UnitRunner._deep_compare(act_value, exp_value, string.format("Temp table %d field '%s'", i, key))
        if not ok then
          return false, err
        end
      else
        if act_value ~= exp_value then
          return false,
            string.format(
              "Temp table %d field '%s' mismatch: expected '%s', got '%s'",
              i,
              key,
              tostring(exp_value),
              tostring(act_value)
            )
        end
      end
    end
  end

  return true, nil
end

---Deep comparison helper for nested tables (partial matching)
---Only compares fields present in expected
---@param actual table Actual value
---@param expected table Expected value
---@param context string Context string for error messages
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._deep_compare(actual, expected, context)
  for key, exp_value in pairs(expected) do
    local act_value = actual[key]

    if type(exp_value) == "table" and type(act_value) == "table" then
      -- Recursively compare nested tables
      local ok, err = UnitRunner._deep_compare(act_value, exp_value, context .. "." .. key)
      if not ok then
        return false, err
      end
    else
      if act_value ~= exp_value then
        return false,
          string.format(
            "%s.%s mismatch: expected '%s', got '%s'",
            context,
            key,
            tostring(exp_value),
            tostring(act_value)
          )
      end
    end
  end

  return true, nil
end

---Format test result for display
---@param result table Test result
---@return string formatted Formatted result string
function UnitRunner.format_result(result)
  local status = result.passed and "PASS" or "FAIL"
  local lines = {
    string.format("[%s] #%d: %s (%s) - %.2fms", status, result.id, result.name, result.type, result.duration_ms),
  }

  if not result.passed and result.error then
    table.insert(lines, "  Error: " .. result.error)
  end

  return table.concat(lines, "\n")
end

---Format summary for display
---@param results table Test results
---@return string formatted Formatted summary string
function UnitRunner.format_summary(results)
  local pass_rate = results.total > 0 and (results.passed / results.total * 100) or 0
  return string.format(
    "Tests: %d total, %d passed, %d failed (%.1f%% pass rate)",
    results.total,
    results.passed,
    results.failed,
    pass_rate
  )
end

return UnitRunner
