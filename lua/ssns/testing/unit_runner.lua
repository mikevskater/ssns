---@class UnitRunner
---Lightweight unit test runner for tokenizer and parser tests
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
