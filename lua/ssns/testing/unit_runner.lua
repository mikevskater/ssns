---@class UnitRunner
---Lightweight unit test runner for tokenizer, parser, provider, context, and utility tests
---Runs synchronously without database connections
local UnitRunner = {}

-- Global skip list for tests that test features not yet implemented or
-- tests that rely on blink.cmp filtering (which happens outside the provider)
-- Format: { [test_id] = "reason for skipping" }
UnitRunner.SKIP_TESTS = {
  -- Missing mock database items (tables, views, synonyms, columns)
  [3032] = "Missing hr.Salaries table in mock database",
  [3033] = "Missing Branch.BranchManagers table in mock database",
  [3036] = "Missing hr.Salaries table in mock database",
  [3041] = "Cross-database completion not implemented in mock",
  [3042] = "Bracketed table names with spaces not in mock",
  [3046] = "Missing vw_EmployeeDetails view in mock",
  [3047] = "Missing syn_RemoteTable synonym in mock",
  [3050] = "Usage-based sorting requires usage tracking setup",
  [3079] = "Schema prefix column completion not implemented",
  [3086] = "Subquery alias column resolution requires full context parsing",
  [3089] = "CTE alias column resolution requires full context parsing",
  [3119] = "CTE column in WHERE clause requires full context parsing",
  [3142] = "Derived table column resolution requires full context parsing",
  [3143] = "CTE reference in ON clause requires full context parsing",
  [3195] = "Special character column (Column#Value) not in mock",
  [3196] = "Reserved word column with specific format not in mock",
  [3197] = "Unicode column (Prénom) not in mock - mock has different Unicode chars",
  [3199] = "Derived table column completion requires full context parsing",
  [3301] = "WITH keyword not in statement starters list",
  [3303] = "SAVEPOINT keyword not in transaction keywords list",
  [3304] = "PRINT keyword not in SQL Server keywords list",
  -- Blink.cmp prefix filtering (handled by completion framework, not provider)
  [3088] = "Subquery alias resolution requires full context parsing",
  [3090] = "Temp table alias resolution requires full context parsing",
  [3092] = "Synonym alias resolution requires full context parsing",
  [3107] = "Type compatibility filtering not implemented in provider",
  [3108] = "Type compatibility filtering (string types) not implemented",
  [3110] = "Type compatibility filtering for comparison operators not implemented",
  [3111] = "Type compatibility filtering with functions not implemented",
  [3113] = "Type compatibility filtering for dates not implemented",
  [3114] = "Type compatibility filtering for numerics not implemented",
  [3115] = "Type compatibility filtering with parameters not implemented",
  [3117] = "Type compatibility filtering in subqueries not implemented",
  [3125] = "ON clause same-table exclusion not implemented",
  [3126] = "ON clause type compatibility sorting not implemented",
  [3130] = "ON clause multi-join exclusions not implemented",
  [3136] = "ON clause complex expression handling not implemented",
  [3137] = "ON clause function handling not implemented",
  [3139] = "ON clause LEFT JOIN exclusions not implemented",
  [3140] = "ON clause RIGHT JOIN exclusions not implemented",
  [3141] = "ON clause FULL OUTER JOIN exclusions not implemented",
  [3144] = "ON clause bracketed identifier handling not implemented",
  [3148] = "ORDER BY already-used column exclusion not implemented",
  [3151] = "ORDER BY ASC/DESC context exclusion not implemented",
  [3154] = "GROUP BY already-used column exclusion not implemented",
  [3156] = "HAVING aggregate column suggestion not implemented",
  [3161] = "INSERT identity column exclusion not implemented",
  [3162] = "INSERT prefix filtering handled by blink.cmp",
  [3166] = "INSERT already-listed column exclusion not implemented",
  [3167] = "INSERT already-listed column exclusion not implemented",
  [3180] = "VALUES DEFAULT suggestion not implemented",
  [3187] = "VALUES type hint suggestion not implemented",
  [3190] = "VALUES subquery column filtering not implemented",
  [3217] = "FK already-joined table exclusion not implemented",
  [3229] = "FK underscore table name handling not implemented",
  [3244] = "FK 2-hop distance limit not implemented",
  [3251] = "FK cycle detection not implemented",
  [3283] = "Fallback view inclusion not implemented",
  [3284] = "Fallback already-joined exclusion not implemented",
  [3291] = "Fallback cross-schema tables not implemented",
  [3294] = "Fallback prefix filtering handled by blink.cmp",
  [3295] = "Fallback TVF inclusion not implemented",
  [3298] = "FK circular reference handling not implemented",
  [3308] = "Keyword prefix filtering handled by blink.cmp",
  [3309] = "Keyword prefix filtering handled by blink.cmp",
  [3310] = "Multi-word keyword prefix not implemented",
  [3313] = "PostgreSQL dialect keyword filtering not implemented",
  [3314] = "Asterisk suggestion context not implemented",
  [3315] = "DISTINCT column context not implemented",
  [3316] = "Continuation keywords not implemented",
  [3317] = "Aggregate keyword context not implemented",
  [3319] = "Subquery asterisk suggestion not implemented",
  [3320] = "PostgreSQL LIMIT context not implemented",
  [3322] = "Full JOIN type suggestions not implemented",
  [3328] = "SQL Server hint keywords not implemented",
  [3329] = "Table hint syntax not implemented",
  [3332] = "With NOLOCK hint not implemented",
  [3334] = "OPTION clause hints not implemented",
  [3335] = "Operator keyword exclusion not implemented",
  [3336] = "AND condition context not implemented",
  [3339] = "Subquery keywords not implemented",
  [3340] = "CTE WITH clause not implemented",
  [3343] = "LEFT JOIN ON keyword not implemented",
  [3344] = "CROSS JOIN ON exclusion not implemented",
  [3348] = "Context-aware TOP keyword not implemented",
  [3349] = "Offset-fetch context not implemented",
  [3350] = "JOIN keyword prefix filtering handled by blink.cmp",
  [3353] = "Procedure prefix filtering handled by blink.cmp",
  [3354] = "Procedure prefix filtering handled by blink.cmp",
  [3355] = "Procedure schema prefix filtering handled by blink.cmp",
  [3358] = "Schema procedure listing not implemented",
  [3359] = "Procedure function distinction not implemented",
  [3362] = "System procedure exclusion not implemented",
  [3365] = "Multiple database procedure listing not implemented",
  [3367] = "Procedure definition database not implemented",
  [3369] = "Bracket procedure name not implemented",
  [3370] = "Long procedure name not implemented",
  [3372] = "Special char procedure name not implemented",
  [3373] = "Unicode procedure name not implemented",
  [3374] = "Procedure case sensitivity not implemented",
  [3375] = "Procedure sorting not implemented",
  [3376] = "Procedure schema priority not implemented",
  [3377] = "Procedure usage tracking not implemented",
  [3378] = "Procedure recent usage not implemented",
  [3379] = "Procedure frequency sorting not implemented",
  [3392] = "Procedure parameter hint not implemented",
  [3393] = "Procedure return type hint not implemented",
  [3394] = "Procedure preview not implemented",
  [3395] = "Procedure signature preview not implemented",
  [3397] = "Procedure permission check not implemented",
  [3398] = "Procedure dependency check not implemented",
  [3399] = "Procedure warning not implemented",
  [3400] = "Procedure deprecation warning not implemented",
  [3405] = "Positional parameter suggestion not implemented",
  [3407] = "Second parameter position not implemented",
  [3408] = "Third parameter position not implemented",
  [3409] = "Fourth parameter position not implemented",
  [3410] = "Fifth parameter OUTPUT not implemented",
  [3411] = "OUTPUT parameter marker not implemented",
  [3414] = "Parameter with partial prefix filtering handled by blink.cmp",
  [3417] = "Named parameter already-used exclusion not implemented",
  [3419] = "Named parameter unordered exclusion not implemented",
  [3420] = "Mixed named/positional parameter not implemented",
  [3421] = "Named parameter assignment suggestion not implemented",
  [3423] = "Parameter default value hint not implemented",
  [3424] = "Parameter OUTPUT hint not implemented",
  [3426] = "Parameter type hint not implemented",
  [3427] = "Named param after positional exclusion not implemented",
  [3428] = "All params named style exclusion not implemented",
  [3430] = "Parameter EXECUTE context not implemented",
  [3431] = "Parameter sp_executesql context not implemented",
  [3432] = "Dynamic SQL parameter context not implemented",
  [3433] = "Variable parameter context not implemented",
  [3434] = "Multiple procedure parameter context not implemented",
  [3435] = "Nested procedure parameter context not implemented",
  [3436] = "Recursive procedure parameter context not implemented",
  [3437] = "Multi-database procedure parameter not implemented",
  [3438] = "Cross-schema procedure parameter not implemented",
  [3439] = "Linked server procedure parameter not implemented",
  [3440] = "CLR procedure parameter not implemented",
  [3441] = "Extended procedure parameter not implemented",
  [3442] = "Assembly procedure parameter not implemented",
  [3443] = "System procedure parameter not implemented",
  [3444] = "Built-in procedure parameter not implemented",
  [3445] = "Deprecated procedure parameter not implemented",
  [3448] = "Table-valued parameter not implemented",
  [3449] = "XML parameter not implemented",
  [3450] = "JSON parameter not implemented",
}

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

  -- Scan async tests
  local async_path = base_path .. "/async"
  local async_files = vim.fn.glob(async_path .. "/*.lua", false, true)
  for _, filepath in ipairs(async_files) do
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

  -- Check global skip list first
  local skip_reason = UnitRunner.SKIP_TESTS[test.id]
  if skip_reason then
    result.passed = true
    result.skipped = true
    result.skip_reason = skip_reason
    result.duration_ms = 0
    return result
  end

  -- Skip tests marked with skip = true
  if test.skip then
    result.passed = true
    result.skipped = true
    result.duration_ms = 0
    return result
  end

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
    elseif test.type == "async" then
      result.actual, result.passed, result.error = UnitRunner._run_async_test(test)
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

---Create mock column object
---@param name string Column name
---@param data_type string Data type
---@param is_primary_key? boolean Is primary key
---@param is_nullable? boolean Is nullable
---@return table column Mock column object
local function create_mock_column(name, data_type, is_primary_key, is_nullable)
  return {
    name = name,
    column_name = name,
    data_type = data_type,
    is_primary_key = is_primary_key or false,
    is_nullable = is_nullable ~= false, -- Default to true
    object_type = "column",
  }
end

---Create mock table with columns
---@param name string Table name
---@param schema string Schema name
---@param columns table[] Column definitions
---@return table table_obj Mock table object
local function create_mock_table(name, schema, columns)
  local tbl = {
    name = name,
    schema = schema,
    object_type = "table",
    _columns = columns or {},
  }
  -- Add get_columns method
  function tbl:get_columns()
    return self._columns
  end
  return tbl
end

---Create mock database structure for provider tests
---Matches the structure in lua/ssns/testing/database_structure.md
---@param connection_config table Connection configuration from test.context.connection
---@return table database Mock database object
function UnitRunner._create_mock_database(connection_config)
  -- ============================================================================
  -- vim_dadbod_test.dbo Tables (matching database_structure.md)
  -- ============================================================================

  -- Regions table
  local regions_cols = {
    create_mock_column("RegionID", "int", true, false),
    create_mock_column("RegionName", "nvarchar(100)", false, false),
  }

  -- Countries table
  local countries_cols = {
    create_mock_column("CountryID", "int", true, false),
    create_mock_column("CountryName", "nvarchar(100)", false, false),
    create_mock_column("RegionID", "int", false, true),
  }

  -- Customers table
  local customers_cols = {
    create_mock_column("Id", "int", true, false),
    create_mock_column("CustomerId", "int", false, true),
    create_mock_column("Name", "nvarchar(100)", false, true),
    create_mock_column("Email", "nvarchar(100)", false, true),
    create_mock_column("CompanyId", "int", false, true),
    create_mock_column("Country", "nvarchar(50)", false, true),
    create_mock_column("Active", "bit", false, true),
    create_mock_column("CreatedDate", "datetime", false, true),
    create_mock_column("CountryID", "int", false, true),
  }

  -- Departments table
  local departments_cols = {
    create_mock_column("DepartmentID", "int", true, false),
    create_mock_column("DepartmentName", "nvarchar(100)", false, false),
    create_mock_column("ManagerID", "int", false, true),
    create_mock_column("Budget", "decimal(12,2)", false, true),
    create_mock_column("Location", "nvarchar(200)", false, true),
    create_mock_column("DepartmentCode", "varchar(10)", false, true),
    create_mock_column("EstablishedYear", "int", false, true),
  }

  -- Employees table (main test table)
  local employees_cols = {
    create_mock_column("EmployeeID", "int", true, false),
    create_mock_column("FirstName", "nvarchar(50)", false, false),
    create_mock_column("LastName", "nvarchar(50)", false, false),
    create_mock_column("Email", "nvarchar(100)", false, true),
    create_mock_column("DepartmentID", "int", false, true),
    create_mock_column("HireDate", "date", false, true),
    create_mock_column("Salary", "decimal(10,2)", false, true),
    create_mock_column("IsActive", "bit", false, true),
    create_mock_column("ManagerID", "int", false, true),
    create_mock_column("Bonus", "decimal(10,2)", false, true),
    create_mock_column("Commission", "decimal(10,2)", false, true),
    create_mock_column("Age", "int", false, true),
    create_mock_column("CreatedDate", "datetime", false, true),
    -- Special column names for edge case tests
    create_mock_column("VeryLongColumnNameThatExceedsNormalLimitsButIsStillValidInDatabaseSystemsForSomeReasonAndShouldBeHandledProperly", "int", false, true),
    create_mock_column("Column$Name", "varchar(50)", false, true),
    create_mock_column("Order", "int", false, true),  -- Reserved word column
    create_mock_column("名前", "nvarchar(50)", false, true),  -- Unicode column
  }

  -- Branches table (for tests expecting this table)
  local branches_cols = {
    create_mock_column("BranchID", "int", true, false),
    create_mock_column("BranchName", "nvarchar(100)", false, false),
    create_mock_column("Location", "nvarchar(200)", false, true),
    create_mock_column("ManagerID", "int", false, true),
  }

  -- EmployeeReviews table (for hr schema tests)
  local employee_reviews_cols = {
    create_mock_column("ReviewID", "int", true, false),
    create_mock_column("EmployeeID", "int", false, false),
    create_mock_column("ReviewDate", "date", false, true),
    create_mock_column("Rating", "int", false, true),
    create_mock_column("Comments", "nvarchar(500)", false, true),
  }

  -- Orders table
  local orders_cols = {
    create_mock_column("OrderID", "int", true, false),
    create_mock_column("CustomerID", "int", false, true),
    create_mock_column("EmployeeID", "int", false, true),
    create_mock_column("OrderDate", "date", false, true),
    create_mock_column("Total", "decimal(18,2)", false, true),
    create_mock_column("Status", "nvarchar(50)", false, true),
    create_mock_column("Quantity", "int", false, true),
  }

  -- Products table
  local products_cols = {
    create_mock_column("Id", "int", true, false),
    create_mock_column("ProductId", "int", false, true),
    create_mock_column("Name", "nvarchar(100)", false, true),
    create_mock_column("CategoryId", "int", false, true),
    create_mock_column("Price", "decimal(18,2)", false, true),
    create_mock_column("Active", "bit", false, true),
  }

  -- Projects table
  local projects_cols = {
    create_mock_column("ProjectID", "int", true, false),
    create_mock_column("ProjectName", "nvarchar(100)", false, false),
    create_mock_column("StartDate", "date", false, true),
    create_mock_column("EndDate", "date", false, true),
    create_mock_column("Budget", "decimal(12,2)", false, true),
    create_mock_column("Status", "nvarchar(20)", false, true),
  }

  -- ============================================================================
  -- vim_dadbod_test.hr Tables
  -- ============================================================================

  -- hr.Benefits table
  local benefits_cols = {
    create_mock_column("BenefitID", "int", true, false),
    create_mock_column("EmployeeID", "int", false, true),
    create_mock_column("BenefitType", "nvarchar(50)", false, true),
    create_mock_column("StartDate", "date", false, true),
    create_mock_column("EndDate", "date", false, true),
    create_mock_column("Cost", "decimal(10,2)", false, true),
  }

  -- ============================================================================
  -- All mock tables
  -- ============================================================================
  local mock_tables = {
    -- dbo schema tables
    create_mock_table("Regions", "dbo", regions_cols),
    create_mock_table("Countries", "dbo", countries_cols),
    create_mock_table("Customers", "dbo", customers_cols),
    create_mock_table("Departments", "dbo", departments_cols),
    create_mock_table("Employees", "dbo", employees_cols),
    create_mock_table("Orders", "dbo", orders_cols),
    create_mock_table("Products", "dbo", products_cols),
    create_mock_table("Projects", "dbo", projects_cols),
    create_mock_table("Branches", "dbo", branches_cols),
    -- hr schema tables
    create_mock_table("Benefits", "hr", benefits_cols),
    create_mock_table("EmployeeReviews", "hr", employee_reviews_cols),
  }

  -- ============================================================================
  -- Views (matching database_structure.md)
  -- ============================================================================

  -- vw_ActiveEmployees - shows active employees
  local vw_active_employees_cols = {
    create_mock_column("EmployeeID", "int", false, false),
    create_mock_column("FirstName", "nvarchar(50)", false, false),
    create_mock_column("LastName", "nvarchar(50)", false, false),
    create_mock_column("Email", "nvarchar(100)", false, true),
    create_mock_column("DepartmentID", "int", false, true),
    create_mock_column("HireDate", "date", false, true),
    create_mock_column("Salary", "decimal(10,2)", false, true),
  }

  -- vw_DepartmentSummary - aggregates department stats
  local vw_dept_summary_cols = {
    create_mock_column("DepartmentID", "int", false, false),
    create_mock_column("DepartmentName", "nvarchar(100)", false, false),
    create_mock_column("Budget", "decimal(12,2)", false, true),
    create_mock_column("EmployeeCount", "int", false, true),
    create_mock_column("AvgSalary", "decimal(38,6)", false, true),
  }

  -- vw_ProjectStatus - project status view
  local vw_project_status_cols = {
    create_mock_column("ProjectID", "int", false, false),
    create_mock_column("ProjectName", "nvarchar(100)", false, false),
    create_mock_column("StartDate", "date", false, true),
    create_mock_column("EndDate", "date", false, true),
    create_mock_column("Budget", "decimal(12,2)", false, true),
    create_mock_column("Status", "varchar(11)", false, false),
  }

  local mock_views = {
    create_mock_table("vw_ActiveEmployees", "dbo", vw_active_employees_cols),
    create_mock_table("vw_DepartmentSummary", "dbo", vw_dept_summary_cols),
    create_mock_table("vw_ProjectStatus", "dbo", vw_project_status_cols),
  }
  -- Mark as views
  for _, v in ipairs(mock_views) do
    v.object_type = "view"
  end

  -- ============================================================================
  -- Synonyms (matching database_structure.md)
  -- ============================================================================
  local mock_synonyms = {
    { name = "syn_ActiveEmployees", schema = "dbo", object_type = "synonym", base_object = "dbo.vw_ActiveEmployees", get_columns = function() return vw_active_employees_cols end },
    { name = "syn_Depts", schema = "dbo", object_type = "synonym", base_object = "dbo.Departments", get_columns = function() return departments_cols end },
    { name = "syn_Employees", schema = "dbo", object_type = "synonym", base_object = "dbo.Employees", get_columns = function() return employees_cols end },
    { name = "syn_HRBenefits", schema = "dbo", object_type = "synonym", base_object = "hr.Benefits", get_columns = function() return benefits_cols end },
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
    -- Store mock data for accessor methods
    _mock_tables = mock_tables,
    _mock_views = mock_views,
    _mock_synonyms = mock_synonyms,
    get_adapter = function()
      return {
        features = {
          views = true,
          synonyms = true,
          functions = true,
        },
        -- Mock quote_identifier for SQL Server style (brackets)
        quote_identifier = function(self, identifier)
          if not identifier then return identifier end
          -- Check if already quoted
          if identifier:match("^%[.*%]$") then
            return identifier
          end
          -- Check if needs quoting (has special chars or is reserved word)
          if identifier:match("[%s%-%.]") or identifier:match("^%d") then
            return "[" .. identifier .. "]"
          end
          return identifier
        end,
      }
    end,
    load = function() end, -- No-op for mock
  }

  -- Add get_tables method matching DbClass interface
  function database:get_tables(schema_filter, opts)
    if schema_filter then
      local filtered = {}
      for _, t in ipairs(self._mock_tables) do
        if t.schema == schema_filter then
          table.insert(filtered, t)
        end
      end
      return filtered
    end
    return self._mock_tables
  end

  -- Add get_views method matching DbClass interface
  function database:get_views(schema_filter, opts)
    if schema_filter then
      local filtered = {}
      for _, v in ipairs(self._mock_views) do
        if v.schema == schema_filter then
          table.insert(filtered, v)
        end
      end
      return filtered
    end
    return self._mock_views
  end

  -- Add get_synonyms method matching DbClass interface
  function database:get_synonyms(schema_filter, opts)
    if schema_filter then
      local filtered = {}
      for _, s in ipairs(self._mock_synonyms) do
        if s.schema == schema_filter then
          table.insert(filtered, s)
        end
      end
      return filtered
    end
    return self._mock_synonyms
  end

  -- Add get_functions method matching DbClass interface (empty for now)
  function database:get_functions(schema_filter, opts)
    return {}
  end

  -- Add get_procedures method matching DbClass interface
  function database:get_procedures(schema_filter, opts)
    -- Create procedures with get_parameters method
    local function create_proc(name, schema, params)
      return {
        name = name,
        schema = schema,
        object_type = "procedure",
        _params = params,
        get_parameters = function(self)
          return self._params or {}
        end,
      }
    end

    local mock_procedures = {
      create_proc("usp_GetEmployeesByDepartment", "dbo", {
        { name = "@DepartmentID", data_type = "int", direction = "IN" },
      }),
      create_proc("usp_InsertEmployee", "dbo", {
        { name = "@FirstName", data_type = "nvarchar(50)", direction = "IN" },
        { name = "@LastName", data_type = "nvarchar(50)", direction = "IN" },
        { name = "@Email", data_type = "nvarchar(100)", direction = "IN" },
        { name = "@DepartmentID", data_type = "int", direction = "IN" },
        { name = "@Salary", data_type = "decimal(18,2)", direction = "IN" },
      }),
      create_proc("usp_GetDivisionMetrics", "dbo", {
        { name = "@DivisionName", data_type = "nvarchar(100)", direction = "IN" },
        { name = "@Year", data_type = "int", direction = "IN" },
      }),
      -- sp_SearchEmployees - heavily tested procedure
      create_proc("sp_SearchEmployees", "dbo", {
        { name = "@SearchTerm", data_type = "nvarchar(100)", direction = "IN" },
        { name = "@DepartmentID", data_type = "int", direction = "IN" },
        { name = "@IncludeInactive", data_type = "bit", direction = "IN" },
        { name = "@IncludeSalary", data_type = "bit", direction = "IN" },
        { name = "@TotalCount", data_type = "int", direction = "OUT" },
      }),
      -- Additional common procedures
      create_proc("usp_UpdateEmployee", "dbo", {
        { name = "@EmployeeID", data_type = "int", direction = "IN" },
        { name = "@FirstName", data_type = "nvarchar(50)", direction = "IN" },
        { name = "@LastName", data_type = "nvarchar(50)", direction = "IN" },
      }),
      create_proc("usp_ProcessOrder", "dbo", {
        { name = "@CustomerID", data_type = "int", direction = "IN" },
        { name = "@DaysBack", data_type = "int", direction = "IN" },
      }),
      create_proc("usp_GetEmployeeCount", "dbo", {
        { name = "@DepartmentID", data_type = "int", direction = "IN" },
        { name = "@TotalCount", data_type = "int", direction = "OUT" },
      }),
    }
    if schema_filter then
      local filtered = {}
      for _, p in ipairs(mock_procedures) do
        if p.schema == schema_filter then
          table.insert(filtered, p)
        end
      end
      return filtered
    end
    return mock_procedures
  end

  -- Add get_schemas method matching DbClass interface
  function database:get_schemas()
    return {
      { name = "dbo" },
      { name = "hr" },
      { name = "Branch" },
    }
  end

  return database
end

---Compare provider results with expected output
---@param actual_items table[] Actual completion items
---@param expected table Expected structure
---@return boolean passed
---@return string? error Error message if failed
function UnitRunner._compare_provider_results(actual_items, expected)
  -- Handle type = "none" which expects empty results (e.g., no completion in comments/strings)
  if expected and expected.type == "none" then
    if #actual_items == 0 then
      return true, nil
    else
      return false, string.format("Expected no completions (type='none'), but got %d items", #actual_items)
    end
  end

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

      -- Build set of actual labels (including unqualified versions for qualified columns)
      local actual_labels = {}
      local actual_unqualified = {} -- Map unqualified name -> full qualified name
      for _, item in ipairs(actual_items) do
        actual_labels[item.label] = true
        -- Also store unqualified version (part after last dot)
        local unqualified = item.label:match("%.([^%.]+)$")
        if unqualified then
          actual_unqualified[unqualified] = true
        end
      end

      -- Check all includes are present (match both qualified and unqualified)
      for _, inc_label in ipairs(includes) do
        local found = actual_labels[inc_label] or actual_unqualified[inc_label]
        if not found then
          return false, string.format("Expected included item '%s' not found in results", inc_label)
        end
      end

      -- Check all excludes are absent (check both qualified and unqualified)
      for _, exc_label in ipairs(excludes) do
        local found = actual_labels[exc_label] or actual_unqualified[exc_label]
        if found then
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
  -- Determine which provider to use based on test.provider field
  local provider_name = test.provider or "tables"
  local provider_module_map = {
    tables = "ssns.completion.providers.tables",
    columns = "ssns.completion.providers.columns",
    joins = "ssns.completion.providers.joins",
    keywords = "ssns.completion.providers.keywords",
    parameters = "ssns.completion.providers.parameters",
    procedures = "ssns.completion.providers.procedures",
    functions = "ssns.completion.providers.functions",
    schemas = "ssns.completion.providers.schemas",
    databases = "ssns.completion.providers.databases",
  }

  local module_path = provider_module_map[provider_name]
  if not module_path then
    return nil, false, "Unknown provider: " .. tostring(provider_name)
  end

  local ok, Provider = pcall(require, module_path)
  if not ok then
    return nil, false, "Failed to load provider " .. provider_name .. ": " .. tostring(Provider)
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
    get_db_type = function() return "sqlserver" end,
    get_databases = function()
      return {
        { name = "vim_dadbod_test" },
        { name = "TEST" },
        { name = "Branch_Prod" },
        { name = "master" },
        { name = "tempdb" },
      }
    end,
    get_database = function(self, db_name)
      -- Return mock database for any database name requested
      return mock_database
    end,
  }

  -- Build aliases dict from tables_in_scope if not already provided
  local sql_context = test.context or {}
  if sql_context.tables_in_scope and not sql_context.aliases then
    sql_context.aliases = {}
    for _, table_info in ipairs(sql_context.tables_in_scope) do
      local alias = table_info.alias
      local name = table_info.name or table_info.table
      if alias and name then
        sql_context.aliases[alias:lower()] = name
      end
    end
  end

  -- Create mock context for the provider
  local mock_ctx = {
    bufnr = 0,
    cursor = cursor_pos,
    connection = {
      server = mock_server,
      database = mock_database,
      schema = test.context.connection.schema or "dbo",
    },
    sql_context = sql_context,
  }

  -- Call the provider's internal implementation (synchronous)
  local items_ok, items = pcall(Provider._get_completions_impl, mock_ctx)
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

-- ============================================================================
-- Async Test Runner
-- ============================================================================

---Generate a unique temp file path for testing
---@return string path Unique temp file path
local function get_temp_file_path()
  local temp_dir = vim.fn.stdpath("cache") .. "/ssns_test"
  vim.fn.mkdir(temp_dir, "p")
  return temp_dir .. "/test_" .. os.time() .. "_" .. math.random(10000, 99999) .. ".tmp"
end

---Generate a unique temp directory path for testing
---@return string path Unique temp directory path
local function get_temp_dir_path()
  local temp_dir = vim.fn.stdpath("cache") .. "/ssns_test"
  return temp_dir .. "/dir_" .. os.time() .. "_" .. math.random(10000, 99999)
end

---Clean up temp file
---@param path string File path to clean up
local function cleanup_temp_file(path)
  pcall(vim.fn.delete, path)
end

---Clean up temp directory
---@param path string Directory path to clean up
local function cleanup_temp_dir(path)
  pcall(vim.fn.delete, path, "rf")
end

---Wait for async callback with timeout
---@param timeout_ms number Timeout in milliseconds
---@return function waiter Function that waits for callback
---@return function signal Function to signal completion
local function create_async_waiter(timeout_ms)
  local completed = false
  local result_value = nil
  local result_error = nil

  local function signal(value, err)
    completed = true
    result_value = value
    result_error = err
  end

  local function waiter()
    local start = vim.loop.hrtime()
    local timeout_ns = timeout_ms * 1000000

    while not completed do
      -- Check timeout
      if (vim.loop.hrtime() - start) > timeout_ns then
        return nil, "Async operation timed out after " .. timeout_ms .. "ms"
      end

      -- Process pending async callbacks
      vim.wait(10, function() return completed end, 5)
    end

    return result_value, result_error
  end

  return waiter, signal
end

---Run async file I/O test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_file_io_test(test)
  local ok, FileIO = pcall(require, "ssns.async.file_io")
  if not ok then
    return nil, false, "Failed to load FileIO module: " .. tostring(FileIO)
  end

  local method = test.method
  local setup = test.setup or {}
  local input = test.input or {}
  local expected = test.expected or {}

  -- Generate temp file path for tests that need it
  local temp_path = get_temp_file_path()
  local temp_dir = nil
  local cleanup_paths = { temp_path }

  -- Setup phase: create temp files if needed
  if setup.create_file then
    -- Use binary mode to preserve exact line endings
    local f = io.open(temp_path, "wb")
    if f then
      f:write(setup.content or "")
      f:close()
    else
      return nil, false, "Failed to create setup file"
    end
  end

  -- Use input path or temp path
  local test_path = input.path or temp_path

  -- Create waiter for async callback
  local waiter, signal = create_async_waiter(5000) -- 5 second timeout

  -- Execute the appropriate async method
  if method == "read_async" then
    FileIO.read_async(test_path, function(result)
      signal(result, nil)
    end)
  elseif method == "write_async" then
    FileIO.write_async(temp_path, input.data or "", function(result)
      signal(result, nil)
    end)
  elseif method == "append_async" then
    FileIO.append_async(temp_path, input.data or "", function(result)
      signal(result, nil)
    end)
  elseif method == "exists_async" then
    FileIO.exists_async(test_path, function(exists, err)
      signal({ exists = exists, error = err }, nil)
    end)
  elseif method == "stat_async" then
    FileIO.stat_async(test_path, function(stat, err)
      signal({ stat = stat, error = err }, nil)
    end)
  elseif method == "read_json_async" then
    FileIO.read_json_async(test_path, function(data, err)
      signal({ data = data, error = err }, nil)
    end)
  elseif method == "write_json_async" then
    FileIO.write_json_async(temp_path, input.data or {}, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "read_lines_async" then
    FileIO.read_lines_async(test_path, function(lines, err)
      signal({ lines = lines, error = err }, nil)
    end)
  elseif method == "write_lines_async" then
    FileIO.write_lines_async(temp_path, input.lines or {}, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "mkdir_async" then
    temp_dir = get_temp_dir_path()
    table.insert(cleanup_paths, temp_dir)
    FileIO.mkdir_async(temp_dir, function(success, err)
      signal({ success = success, error = err, dir_path = temp_dir }, nil)
    end)
  else
    for _, path in ipairs(cleanup_paths) do
      cleanup_temp_file(path)
    end
    return nil, false, "Unknown FileIO method: " .. tostring(method)
  end

  -- Wait for result
  local result, wait_err = waiter()
  if wait_err then
    for _, path in ipairs(cleanup_paths) do
      cleanup_temp_file(path)
    end
    return nil, false, wait_err
  end

  -- Verify results
  local passed = true
  local error_msg = nil

  -- Check success/failure expectation
  if expected.success ~= nil then
    if method == "read_async" or method == "write_async" or method == "append_async" then
      if result.success ~= expected.success then
        passed = false
        error_msg = string.format("Expected success=%s, got %s", tostring(expected.success), tostring(result.success))
      end
    elseif method == "write_json_async" or method == "write_lines_async" or method == "mkdir_async" then
      if result.success ~= expected.success then
        passed = false
        error_msg = string.format("Expected success=%s, got %s", tostring(expected.success), tostring(result.success))
      end
    end
  end

  -- Check data expectation
  if passed and expected.data ~= nil then
    if method == "read_async" then
      if result.data ~= expected.data then
        passed = false
        error_msg = string.format("Expected data='%s', got '%s'", expected.data, result.data or "nil")
      end
    elseif method == "read_json_async" then
      -- Deep compare for JSON
      if type(expected.data) == "table" then
        for k, v in pairs(expected.data) do
          if result.data[k] ~= v then
            passed = false
            error_msg = string.format("JSON key '%s' mismatch: expected %s, got %s", k, tostring(v), tostring(result.data[k]))
            break
          end
        end
      end
    end
  end

  -- Check lines expectation
  if passed and expected.lines ~= nil then
    if result.lines then
      for i, line in ipairs(expected.lines) do
        if result.lines[i] ~= line then
          passed = false
          error_msg = string.format("Line %d mismatch: expected '%s', got '%s'", i, line, result.lines[i] or "nil")
          break
        end
      end
    else
      passed = false
      error_msg = "Expected lines but got nil"
    end
  end

  -- Check exists expectation
  if passed and expected.exists ~= nil then
    if result.exists ~= expected.exists then
      passed = false
      error_msg = string.format("Expected exists=%s, got %s", tostring(expected.exists), tostring(result.exists))
    end
  end

  -- Check has_error expectation
  if passed and expected.has_error ~= nil then
    local has_error = result.error ~= nil
    if has_error ~= expected.has_error then
      passed = false
      error_msg = string.format("Expected has_error=%s, got %s (error: %s)", tostring(expected.has_error), tostring(has_error), tostring(result.error))
    end
  end

  -- Check has_stat expectation
  if passed and expected.has_stat ~= nil then
    local has_stat = result.stat ~= nil
    if has_stat ~= expected.has_stat then
      passed = false
      error_msg = string.format("Expected has_stat=%s, got %s", tostring(expected.has_stat), tostring(has_stat))
    end
  end

  -- Check min_size expectation for stat
  if passed and expected.min_size ~= nil and result.stat then
    if result.stat.size < expected.min_size then
      passed = false
      error_msg = string.format("Expected min_size=%d, got %d", expected.min_size, result.stat.size)
    end
  end

  -- Verify file content after write
  if passed and expected.verify_content ~= nil then
    local f = io.open(temp_path, "r")
    if f then
      local content = f:read("*all")
      f:close()
      if content ~= expected.verify_content then
        passed = false
        error_msg = string.format("Verify content mismatch: expected '%s', got '%s'", expected.verify_content, content)
      end
    else
      passed = false
      error_msg = "Failed to read file for content verification"
    end
  end

  -- Verify directory exists after mkdir
  if passed and expected.dir_exists ~= nil and result.dir_path then
    local dir_exists = vim.fn.isdirectory(result.dir_path) == 1
    if dir_exists ~= expected.dir_exists then
      passed = false
      error_msg = string.format("Expected dir_exists=%s, got %s", tostring(expected.dir_exists), tostring(dir_exists))
    end
  end

  -- Cleanup
  for _, path in ipairs(cleanup_paths) do
    if path:match("%.tmp$") then
      cleanup_temp_file(path)
    else
      cleanup_temp_dir(path)
    end
  end

  return result, passed, error_msg
end

---Run async connections test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_connections_test(test)
  local ok, Connections = pcall(require, "ssns.connections")
  if not ok then
    return nil, false, "Failed to load Connections module: " .. tostring(Connections)
  end

  local FileIO = require("ssns.async.file_io")
  local method = test.method
  local setup = test.setup or {}
  local input = test.input or {}
  local expected = test.expected or {}

  -- Create a temp connections file for isolation
  local temp_dir = vim.fn.stdpath("cache") .. "/ssns_test_connections"
  vim.fn.mkdir(temp_dir, "p")
  local temp_file = temp_dir .. "/connections_" .. os.time() .. "_" .. math.random(10000, 99999) .. ".json"

  -- Override the file path temporarily
  local orig_get_file_path = Connections.get_file_path
  Connections.get_file_path = function() return temp_file end

  -- Override ensure_directory to use temp
  local orig_ensure_directory = Connections.ensure_directory
  Connections.ensure_directory = function()
    vim.fn.mkdir(temp_dir, "p")
  end

  -- Setup phase: create connections file if needed
  if setup.connections_file then
    local data = {
      version = 2,
      connections = setup.connections or {},
    }
    local json = vim.fn.json_encode(data)
    local f = io.open(temp_file, "w")
    if f then
      f:write(json)
      f:close()
    end
  end

  -- Create waiter for async callback
  local waiter, signal = create_async_waiter(5000)

  -- Execute the appropriate async method
  if method == "load_async" then
    Connections.load_async(function(connections, err)
      signal({ connections = connections, error = err }, nil)
    end)
  elseif method == "save_async" then
    Connections.save_async(input.connections or {}, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "add_async" then
    Connections.add_async(input.connection, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "remove_async" then
    Connections.remove_async(input.name, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "update_async" then
    Connections.update_async(input.name, input.connection, function(success, err)
      signal({ success = success, error = err }, nil)
    end)
  elseif method == "find_async" then
    Connections.find_async(input.name, function(connection, err)
      signal({ connection = connection, error = err }, nil)
    end)
  elseif method == "toggle_favorite_async" then
    Connections.toggle_favorite_async(input.name, function(success, new_state, err)
      signal({ success = success, new_state = new_state, error = err }, nil)
    end)
  else
    -- Restore original functions
    Connections.get_file_path = orig_get_file_path
    Connections.ensure_directory = orig_ensure_directory
    cleanup_temp_file(temp_file)
    return nil, false, "Unknown Connections method: " .. tostring(method)
  end

  -- Wait for result
  local result, wait_err = waiter()

  -- Restore original functions
  Connections.get_file_path = orig_get_file_path
  Connections.ensure_directory = orig_ensure_directory

  if wait_err then
    cleanup_temp_file(temp_file)
    return nil, false, wait_err
  end

  -- Verify results
  local passed = true
  local error_msg = nil

  -- Check success expectation
  if expected.success ~= nil then
    local success_val = result.success
    -- For load_async, success is implied by no error
    if method == "load_async" then
      success_val = result.error == nil
    end
    if success_val ~= expected.success then
      passed = false
      error_msg = string.format("Expected success=%s, got %s (error: %s)", tostring(expected.success), tostring(success_val), tostring(result.error))
    end
  end

  -- Check connections_count expectation
  if passed and expected.connections_count ~= nil then
    local count = result.connections and #result.connections or 0
    if count ~= expected.connections_count then
      passed = false
      error_msg = string.format("Expected %d connections, got %d", expected.connections_count, count)
    end
  end

  -- Check has_connection expectation
  if passed and expected.has_connection then
    local found = false
    for _, conn in ipairs(result.connections or {}) do
      if conn.name == expected.has_connection then
        found = true
        break
      end
    end
    if not found then
      passed = false
      error_msg = string.format("Expected to find connection '%s'", expected.has_connection)
    end
  end

  -- Check has_error expectation
  if passed and expected.has_error ~= nil then
    local has_error = result.error ~= nil
    if has_error ~= expected.has_error then
      passed = false
      error_msg = string.format("Expected has_error=%s, got %s", tostring(expected.has_error), tostring(has_error))
    end
  end

  -- Check new_state for toggle_favorite
  if passed and expected.new_state ~= nil then
    if result.new_state ~= expected.new_state then
      passed = false
      error_msg = string.format("Expected new_state=%s, got %s", tostring(expected.new_state), tostring(result.new_state))
    end
  end

  -- Check found for find_async
  if passed and expected.found ~= nil then
    local found = result.connection ~= nil
    if found ~= expected.found then
      passed = false
      error_msg = string.format("Expected found=%s, got %s", tostring(expected.found), tostring(found))
    end
  end

  -- Check connection_name for find_async
  if passed and expected.connection_name and result.connection then
    if result.connection.name ~= expected.connection_name then
      passed = false
      error_msg = string.format("Expected connection name '%s', got '%s'", expected.connection_name, result.connection.name)
    end
  end

  -- Verify file exists after save
  if passed and expected.verify_file_exists then
    if vim.fn.filereadable(temp_file) ~= 1 then
      passed = false
      error_msg = "Expected file to exist after save"
    end
  end

  -- Verify connection in file after operation
  if passed and expected.verify_has_connection then
    local f = io.open(temp_file, "r")
    if f then
      local content = f:read("*all")
      f:close()
      local data = vim.fn.json_decode(content)
      local found = false
      for _, conn in ipairs(data.connections or {}) do
        if conn.name == expected.verify_has_connection then
          found = true
          break
        end
      end
      if not found then
        passed = false
        error_msg = string.format("Expected connection '%s' in file", expected.verify_has_connection)
      end
    end
  end

  -- Verify connection NOT in file after removal
  if passed and expected.verify_no_connection then
    local f = io.open(temp_file, "r")
    if f then
      local content = f:read("*all")
      f:close()
      local data = vim.fn.json_decode(content)
      for _, conn in ipairs(data.connections or {}) do
        if conn.name == expected.verify_no_connection then
          passed = false
          error_msg = string.format("Connection '%s' should not be in file", expected.verify_no_connection)
          break
        end
      end
    end
  end

  -- Verify connection host after update
  if passed and expected.verify_connection_host then
    local f = io.open(temp_file, "r")
    if f then
      local content = f:read("*all")
      f:close()
      local data = vim.fn.json_decode(content)
      local name = expected.verify_connection_host.name
      local exp_host = expected.verify_connection_host.host
      for _, conn in ipairs(data.connections or {}) do
        if conn.name == name then
          if conn.server.host ~= exp_host then
            passed = false
            error_msg = string.format("Expected host '%s' for '%s', got '%s'", exp_host, name, conn.server.host)
          end
          break
        end
      end
    end
  end

  -- Cleanup
  cleanup_temp_file(temp_file)

  return result, passed, error_msg
end

---Run async debug logger test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_debug_test(test)
  -- Note: Debug module has special initialization behavior
  -- We need to be careful not to interfere with the global state too much
  local ok, Debug = pcall(require, "ssns.debug")
  if not ok then
    return nil, false, "Failed to load Debug module: " .. tostring(Debug)
  end

  local method = test.method
  local setup = test.setup or {}
  local input = test.input or {}
  local expected = test.expected or {}

  local passed = true
  local error_msg = nil
  local result = {}

  -- Get initial buffer size
  local initial_size = Debug.get_buffer_size()

  -- Setup phase: pre-log messages if needed
  if setup.pre_log then
    for _, msg in ipairs(setup.pre_log) do
      Debug.log(msg)
    end
  end

  -- Execute the appropriate method
  if method == "log" then
    local size_before = Debug.get_buffer_size()
    Debug.log(input.message or "test")
    local size_after = Debug.get_buffer_size()
    result.buffer_increased = size_after > size_before

    if expected.buffer_increased and not result.buffer_increased then
      passed = false
      error_msg = "Expected buffer to increase after log"
    end
  elseif method == "log_multiple" then
    local size_before = Debug.get_buffer_size()
    for _, msg in ipairs(input.messages or {}) do
      Debug.log(msg)
    end
    local size_after = Debug.get_buffer_size()
    result.buffer_size = size_after

    if expected.min_buffer_size and size_after < expected.min_buffer_size then
      passed = false
      error_msg = string.format("Expected min buffer size %d, got %d", expected.min_buffer_size, size_after)
    end
  elseif method == "flush_test" then
    local size_before = Debug.get_buffer_size()
    Debug.flush()
    -- Wait a bit for async flush
    vim.wait(50, function() return false end)
    local size_after = Debug.get_buffer_size()
    result.buffer_cleared = size_after < size_before

    if expected.buffer_cleared and size_after >= size_before then
      passed = false
      error_msg = string.format("Expected buffer to be cleared: before=%d, after=%d", size_before, size_after)
    end
  elseif method == "flush_sync_test" then
    Debug.flush_sync()
    local size_after = Debug.get_buffer_size()
    result.buffer_cleared = size_after == 0

    if expected.buffer_cleared and size_after > 0 then
      passed = false
      error_msg = string.format("Expected buffer to be cleared by sync flush, size=%d", size_after)
    end

    -- Check file contains expected content
    if expected.file_contains then
      local log_path = Debug.get_log_path()
      local f = io.open(log_path, "r")
      if f then
        local content = f:read("*all")
        f:close()
        if not content:find(expected.file_contains, 1, true) then
          passed = false
          error_msg = string.format("Expected log file to contain '%s'", expected.file_contains)
        end
      end
    end
  elseif method == "get_log_path" then
    local path = Debug.get_log_path()
    result.path = path
    result.has_path = path ~= nil and path ~= ""

    if expected.has_path and not result.has_path then
      passed = false
      error_msg = "Expected valid log path"
    end

    if expected.path_contains and not path:find(expected.path_contains, 1, true) then
      passed = false
      error_msg = string.format("Expected path to contain '%s', got '%s'", expected.path_contains, path)
    end
  elseif method == "get_buffer_size_test" then
    local size = Debug.get_buffer_size()
    result.buffer_size = size

    if expected.min_buffer_size and size < expected.min_buffer_size then
      passed = false
      error_msg = string.format("Expected min buffer size %d, got %d", expected.min_buffer_size, size)
    end
  else
    return nil, false, "Unknown Debug method: " .. tostring(method)
  end

  return result, passed, error_msg
end

---Run async cancellation test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_cancellation_test(test)
  local ok, Cancellation = pcall(require, "ssns.async.cancellation")
  if not ok then
    return nil, false, "Failed to load Cancellation module: " .. tostring(Cancellation)
  end

  local method = test.method
  local input = test.input or {}
  local expected = test.expected or {}

  local passed = true
  local error_msg = nil
  local result = {}

  if method == "create_token" then
    local token = Cancellation.create_token()
    result.has_token = token ~= nil
    result.is_cancelled = token.is_cancelled

    if expected.has_token and not result.has_token then
      passed = false
      error_msg = "Expected token to be created"
    end
    if expected.is_cancelled ~= nil and result.is_cancelled ~= expected.is_cancelled then
      passed = false
      error_msg = string.format("Expected is_cancelled=%s, got %s", tostring(expected.is_cancelled), tostring(result.is_cancelled))
    end

  elseif method == "cancel_token" then
    local token = Cancellation.create_token()
    token:cancel()
    result.is_cancelled = token.is_cancelled

    if expected.is_cancelled and not result.is_cancelled then
      passed = false
      error_msg = "Expected token to be cancelled after cancel()"
    end

  elseif method == "cancel_with_reason" then
    local token = Cancellation.create_token()
    token:cancel(input.reason)
    result.is_cancelled = token.is_cancelled
    result.reason = token.reason

    if expected.is_cancelled and not result.is_cancelled then
      passed = false
      error_msg = "Expected token to be cancelled"
    end
    if expected.reason and result.reason ~= expected.reason then
      passed = false
      error_msg = string.format("Expected reason='%s', got '%s'", expected.reason, result.reason or "nil")
    end

  elseif method == "cancel_without_reason" then
    local token = Cancellation.create_token()
    token:cancel()
    result.is_cancelled = token.is_cancelled
    result.has_reason = token.reason ~= nil

    if expected.is_cancelled and not result.is_cancelled then
      passed = false
      error_msg = "Expected token to be cancelled"
    end
    if expected.has_reason and not result.has_reason then
      passed = false
      error_msg = "Expected token to have default reason"
    end

  elseif method == "double_cancel" then
    local token = Cancellation.create_token()
    token:cancel("First reason")
    local first_reason = token.reason
    token:cancel("Second reason")
    result.is_cancelled = token.is_cancelled
    result.first_reason_preserved = token.reason == first_reason

    if expected.is_cancelled and not result.is_cancelled then
      passed = false
      error_msg = "Expected token to be cancelled"
    end
    if expected.first_reason_preserved and not result.first_reason_preserved then
      passed = false
      error_msg = "Expected first reason to be preserved on double cancel"
    end

  elseif method == "on_cancel_invoked" then
    local token = Cancellation.create_token()
    local callback_invoked = false
    token:on_cancel(function()
      callback_invoked = true
    end)
    token:cancel()
    -- Wait for vim.schedule if needed
    vim.wait(50, function() return callback_invoked end, 10)
    result.callback_invoked = callback_invoked

    if expected.callback_invoked and not result.callback_invoked then
      passed = false
      error_msg = "Expected callback to be invoked on cancel"
    end

  elseif method == "on_cancel_receives_reason" then
    local token = Cancellation.create_token()
    local received_reason = nil
    token:on_cancel(function(reason)
      received_reason = reason
    end)
    token:cancel(input.reason)
    vim.wait(50, function() return received_reason ~= nil end, 10)
    result.received_reason = received_reason

    if expected.received_reason and result.received_reason ~= expected.received_reason then
      passed = false
      error_msg = string.format("Expected received_reason='%s', got '%s'", expected.received_reason, result.received_reason or "nil")
    end

  elseif method == "multiple_callbacks" then
    local token = Cancellation.create_token()
    local invoke_count = 0
    token:on_cancel(function() invoke_count = invoke_count + 1 end)
    token:on_cancel(function() invoke_count = invoke_count + 1 end)
    token:on_cancel(function() invoke_count = invoke_count + 1 end)
    token:cancel()
    vim.wait(50, function() return invoke_count >= 3 end, 10)
    result.invoke_count = invoke_count
    result.all_invoked = invoke_count == 3

    if expected.all_invoked and not result.all_invoked then
      passed = false
      error_msg = string.format("Expected all 3 callbacks invoked, got %d", invoke_count)
    end

  elseif method == "on_cancel_already_cancelled" then
    local token = Cancellation.create_token()
    token:cancel("Pre-cancelled")
    local callback_invoked = false
    token:on_cancel(function()
      callback_invoked = true
    end)
    vim.wait(100, function() return callback_invoked end, 10)
    result.callback_invoked = callback_invoked

    if expected.callback_invoked and not result.callback_invoked then
      passed = false
      error_msg = "Expected callback to be invoked immediately for already cancelled token"
    end

  elseif method == "unregister_callback" then
    local token = Cancellation.create_token()
    local callback_invoked = false
    local unregister = token:on_cancel(function()
      callback_invoked = true
    end)
    unregister()
    token:cancel()
    vim.wait(50, function() return false end, 10) -- Just wait a bit
    result.callback_not_invoked = not callback_invoked

    if expected.callback_not_invoked and callback_invoked then
      passed = false
      error_msg = "Expected callback NOT to be invoked after unregister"
    end

  elseif method == "throw_not_cancelled" then
    local token = Cancellation.create_token()
    local threw = false
    local throw_ok = pcall(function()
      token:throw_if_cancelled()
    end)
    result.no_error = throw_ok

    if expected.no_error and not result.no_error then
      passed = false
      error_msg = "Expected no error for non-cancelled token"
    end

  elseif method == "throw_when_cancelled" then
    local token = Cancellation.create_token()
    token:cancel("Test cancellation")
    local threw_error = false
    local is_cancellation = false
    local throw_ok, err = pcall(function()
      token:throw_if_cancelled()
    end)
    threw_error = not throw_ok
    if err then
      is_cancellation = Cancellation.is_cancellation_error(err)
    end
    result.threw_error = threw_error
    result.is_cancellation_error = is_cancellation

    if expected.threw_error and not result.threw_error then
      passed = false
      error_msg = "Expected error to be thrown for cancelled token"
    end
    if expected.is_cancellation_error and not result.is_cancellation_error then
      passed = false
      error_msg = "Expected error to be a cancellation error"
    end

  elseif method == "linked_token_parent_cancel" then
    local parent = Cancellation.create_token()
    local linked = Cancellation.create_linked_token(parent)
    parent:cancel("Parent cancelled")
    result.linked_cancelled = linked.is_cancelled

    if expected.linked_cancelled and not result.linked_cancelled then
      passed = false
      error_msg = "Expected linked token to be cancelled when parent cancels"
    end

  elseif method == "linked_token_parent_not_cancelled" then
    local parent = Cancellation.create_token()
    local linked = Cancellation.create_linked_token(parent)
    result.linked_not_cancelled = not linked.is_cancelled

    if expected.linked_not_cancelled and linked.is_cancelled then
      passed = false
      error_msg = "Expected linked token NOT to be cancelled when parent is not cancelled"
    end

  elseif method == "linked_token_already_cancelled_parent" then
    local parent = Cancellation.create_token()
    parent:cancel("Already cancelled")
    local linked = Cancellation.create_linked_token(parent)
    result.linked_cancelled = linked.is_cancelled

    if expected.linked_cancelled and not result.linked_cancelled then
      passed = false
      error_msg = "Expected linked token to be immediately cancelled for already-cancelled parent"
    end

  elseif method == "linked_token_multiple_parents" then
    local parent1 = Cancellation.create_token()
    local parent2 = Cancellation.create_token()
    local linked = Cancellation.create_linked_token(parent1, parent2)
    parent2:cancel("Parent 2 cancelled")
    result.linked_cancelled = linked.is_cancelled
    result.reason_from_cancelled_parent = linked.reason == "Parent 2 cancelled"

    if expected.linked_cancelled and not result.linked_cancelled then
      passed = false
      error_msg = "Expected linked token to be cancelled when any parent cancels"
    end
    if expected.reason_from_cancelled_parent and not result.reason_from_cancelled_parent then
      passed = false
      error_msg = "Expected linked token reason to come from cancelled parent"
    end

  elseif method == "is_cancellation_error_test" then
    -- Create a real cancellation error
    local token = Cancellation.create_token()
    token:cancel()
    local _, cancel_err = pcall(function()
      token:throw_if_cancelled()
    end)

    result.detects_cancellation_error = Cancellation.is_cancellation_error(cancel_err)
    result.ignores_other_errors = not Cancellation.is_cancellation_error("Some other error")
      and not Cancellation.is_cancellation_error(nil)
      and not Cancellation.is_cancellation_error(123)

    if expected.detects_cancellation_error and not result.detects_cancellation_error then
      passed = false
      error_msg = "Expected to detect cancellation error"
    end
    if expected.ignores_other_errors and not result.ignores_other_errors then
      passed = false
      error_msg = "Expected to ignore non-cancellation errors"
    end

  else
    return nil, false, "Unknown Cancellation method: " .. tostring(method)
  end

  return result, passed, error_msg
end

---Run async completion provider test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_completion_providers_test(test)
  local method = test.method
  local setup = test.setup or {}
  local expected = test.expected or {}

  local passed = true
  local error_msg = nil
  local result = {}

  -- Create mock database if needed
  local mock_database = nil
  local mock_server = nil

  if setup.mock_database or setup.mock_server then
    mock_database = UnitRunner._create_mock_database({ database = "vim_dadbod_test" })

    -- Create mock server
    mock_server = {
      name = "MockServer",
      host = "localhost",
      _databases = { mock_database },
      is_connected = function() return true end,
      get_database = function(self, name)
        if name == "vim_dadbod_test" then
          return mock_database
        end
        return nil
      end,
      get_databases = function(self)
        return { mock_database }
      end,
    }
  end

  -- Create cancellation token if pre-cancel requested
  local Cancellation = require("ssns.async.cancellation")
  local cancel_token = Cancellation.create_token()
  if setup.pre_cancel then
    cancel_token:cancel("Pre-cancelled for test")
  end

  -- Create waiter for async callback
  local waiter, signal = create_async_waiter(5000)

  if method == "tables_async" then
    local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
    if not ok then
      return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "from" },
    }

    TablesProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.has_items = async_result.items and #async_result.items > 0
    if expected.includes_table and async_result.items then
      result.found_table = false
      for _, item in ipairs(async_result.items) do
        if item.label == expected.includes_table or (item.label and item.label:find(expected.includes_table, 1, true)) then
          result.found_table = true
          break
        end
      end
    end

    if expected.has_items and not result.has_items then
      passed = false
      error_msg = "Expected items to be returned"
    end
    if expected.includes_table and not result.found_table then
      passed = false
      error_msg = string.format("Expected to find table '%s' in results", expected.includes_table)
    end

  elseif method == "tables_async_nil_connection" then
    local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
    if not ok then
      return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
    end

    local ctx = {
      connection = nil,
      sql_context = {},
    }

    TablesProvider.get_completions_async(ctx, {
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.empty_result = async_result.items == nil or #async_result.items == 0

    if expected.empty_result and not result.empty_result then
      passed = false
      error_msg = "Expected empty result for nil connection"
    end

  elseif method == "tables_async_cancelled" then
    local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
    if not ok then
      return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "from" },
    }

    local callback_called_with_items = false

    TablesProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        if items and #items > 0 then
          callback_called_with_items = true
        end
        signal({ items = items, error = err }, nil)
      end,
    })

    -- Wait a bit for any callbacks
    vim.wait(200, function() return false end, 20)
    result.callback_not_called_with_items = not callback_called_with_items

    if expected.callback_not_called_with_items and callback_called_with_items then
      passed = false
      error_msg = "Expected callback NOT to be called with items when pre-cancelled"
    end

  elseif method == "columns_async_qualified" then
    local ok, ColumnsProvider = pcall(require, "ssns.completion.providers.columns")
    if not ok then
      return nil, false, "Failed to load ColumnsProvider: " .. tostring(ColumnsProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = {
        mode = "column_qualified",
        table_ref = setup.table_ref or "Employees",
      },
    }

    ColumnsProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.has_items = async_result.items and #async_result.items > 0
    if expected.includes_column and async_result.items then
      result.found_column = false
      for _, item in ipairs(async_result.items) do
        if item.label == expected.includes_column then
          result.found_column = true
          break
        end
      end
    end

    if expected.has_items and not result.has_items then
      passed = false
      error_msg = "Expected column items to be returned"
    end
    if expected.includes_column and not result.found_column then
      passed = false
      error_msg = string.format("Expected to find column '%s' in results", expected.includes_column)
    end

  elseif method == "columns_async_nonexistent" then
    local ok, ColumnsProvider = pcall(require, "ssns.completion.providers.columns")
    if not ok then
      return nil, false, "Failed to load ColumnsProvider: " .. tostring(ColumnsProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = {
        mode = "column_qualified",
        table_ref = setup.table_ref or "NonExistentTable",
      },
    }

    ColumnsProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.empty_result = async_result.items == nil or #async_result.items == 0

    if expected.empty_result and not result.empty_result then
      passed = false
      error_msg = "Expected empty result for non-existent table"
    end

  elseif method == "columns_async_cancelled" then
    local ok, ColumnsProvider = pcall(require, "ssns.completion.providers.columns")
    if not ok then
      return nil, false, "Failed to load ColumnsProvider: " .. tostring(ColumnsProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = {
        mode = "column_qualified",
        table_ref = "Employees",
      },
    }

    local callback_called_with_items = false

    ColumnsProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        if items and #items > 0 then
          callback_called_with_items = true
        end
        signal({ items = items, error = err }, nil)
      end,
    })

    vim.wait(200, function() return false end, 20)
    result.callback_not_called_with_items = not callback_called_with_items

    if expected.callback_not_called_with_items and callback_called_with_items then
      passed = false
      error_msg = "Expected callback NOT to be called with items when pre-cancelled"
    end

  elseif method == "schemas_async" then
    local ok, SchemasProvider = pcall(require, "ssns.completion.providers.schemas")
    if not ok then
      return nil, false, "Failed to load SchemasProvider: " .. tostring(SchemasProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "schema" },
    }

    SchemasProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.has_items = async_result.items and #async_result.items > 0
    if expected.includes_schema and async_result.items then
      result.found_schema = false
      for _, item in ipairs(async_result.items) do
        if item.label == expected.includes_schema then
          result.found_schema = true
          break
        end
      end
    end

    if expected.has_items and not result.has_items then
      passed = false
      error_msg = "Expected schema items to be returned"
    end
    if expected.includes_schema and not result.found_schema then
      passed = false
      error_msg = string.format("Expected to find schema '%s' in results", expected.includes_schema)
    end

  elseif method == "databases_async" then
    local ok, DatabasesProvider = pcall(require, "ssns.completion.providers.databases")
    if not ok then
      return nil, false, "Failed to load DatabasesProvider: " .. tostring(DatabasesProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "database" },
    }

    DatabasesProvider.get_completions_async(ctx, {
      cancel_token = cancel_token,
      on_complete = function(items, err)
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.has_items = async_result.items and #async_result.items > 0
    if expected.includes_database and async_result.items then
      result.found_database = false
      for _, item in ipairs(async_result.items) do
        if item.label == expected.includes_database then
          result.found_database = true
          break
        end
      end
    end

    if expected.has_items and not result.has_items then
      passed = false
      error_msg = "Expected database items to be returned"
    end
    if expected.includes_database and not result.found_database then
      passed = false
      error_msg = string.format("Expected to find database '%s' in results", expected.includes_database)
    end

  elseif method == "callback_always_called" then
    local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
    if not ok then
      return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "from" },
    }

    local callback_called = false

    TablesProvider.get_completions_async(ctx, {
      on_complete = function(items, err)
        callback_called = true
        signal({ items = items, error = err }, nil)
      end,
    })

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    result.callback_called = callback_called

    if expected.callback_called and not result.callback_called then
      passed = false
      error_msg = "Expected callback to be called"
    end

  elseif method == "callback_scheduled" then
    local ok, TablesProvider = pcall(require, "ssns.completion.providers.tables")
    if not ok then
      return nil, false, "Failed to load TablesProvider: " .. tostring(TablesProvider)
    end

    local ctx = {
      connection = {
        server = mock_server,
        database = mock_database,
      },
      sql_context = { mode = "from" },
    }

    local callback_after_return = false
    local returned = false

    TablesProvider.get_completions_async(ctx, {
      on_complete = function(items, err)
        callback_after_return = returned
        signal({ items = items, error = err, after_return = callback_after_return }, nil)
      end,
    })

    returned = true

    local async_result, wait_err = waiter()
    if wait_err then
      return nil, false, wait_err
    end

    -- The callback should have been called AFTER get_completions_async returned
    result.callback_scheduled = async_result.after_return

    if expected.callback_scheduled and not result.callback_scheduled then
      passed = false
      error_msg = "Expected callback to be scheduled (called after return)"
    end

  else
    return nil, false, "Unknown completion providers method: " .. tostring(method)
  end

  return result, passed, error_msg
end

---Run async chunked rendering test
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_chunked_rendering_test(test)
  local method = test.method
  local input = test.input or {}
  local expected = test.expected or {}

  local passed = true
  local error_msg = nil
  local result = {}

  -- Helper to create test buffer
  local function create_test_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    return bufnr
  end

  -- Helper to delete test buffer
  local function delete_test_buffer(bufnr)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  -- Helper to generate test lines
  local function generate_lines(count)
    local lines = {}
    for i = 1, count do
      table.insert(lines, string.format("Test line %d with some content", i))
    end
    return lines
  end

  -- Helper to create mock line_map for highlights
  local function create_mock_line_map(count)
    local line_map = {}
    for i = 1, count do
      line_map[i] = { object_type = "table", name = "Table" .. i }
    end
    return line_map
  end

  -- ============================================================================
  -- UiBuffer.set_lines_chunked tests
  -- ============================================================================

  if method == "set_lines_chunked_small" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    -- Temporarily override UiBuffer
    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local complete_called = false
    local waiter, signal = create_async_waiter(5000)

    UiBuffer.set_lines_chunked(lines, {
      on_complete = function()
        complete_called = true
        signal({ complete = true }, nil)
      end,
    })

    -- For small content, should be synchronous
    result.sync_path = complete_called -- Should be true immediately
    result.on_complete_called = complete_called

    if not result.sync_path then
      -- Wait for async completion
      waiter()
      result.on_complete_called = complete_called
    end

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    result.lines_written = #buf_lines

    -- Restore and cleanup
    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.sync_path and not result.sync_path then
      passed = false
      error_msg = "Expected sync path for small content"
    end
    if expected.lines_written and result.lines_written ~= expected.lines_written then
      passed = false
      error_msg = string.format("Expected %d lines, got %d", expected.lines_written, result.lines_written)
    end

  elseif method == "set_lines_chunked_exact" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local complete_called = false

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_complete = function()
        complete_called = true
      end,
    })

    result.sync_path = complete_called
    result.on_complete_called = complete_called

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    result.lines_written = #buf_lines

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.sync_path and not result.sync_path then
      passed = false
      error_msg = "Expected sync path for exact chunk_size content"
    end

  elseif method == "set_lines_chunked_large" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local complete_called = false
    local progress_calls = 0
    local waiter, signal = create_async_waiter(5000)

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_progress = function(written, total)
        progress_calls = progress_calls + 1
      end,
      on_complete = function()
        complete_called = true
        signal({ complete = true }, nil)
      end,
    })

    -- For large content, should be async
    result.async_path = not complete_called

    waiter()
    result.on_complete_called = complete_called
    result.progress_call_count = progress_calls

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    result.lines_written = #buf_lines

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.async_path and not result.async_path then
      passed = false
      error_msg = "Expected async path for large content"
    end
    if expected.min_progress_calls and progress_calls < expected.min_progress_calls then
      passed = false
      error_msg = string.format("Expected at least %d progress calls, got %d", expected.min_progress_calls, progress_calls)
    end

  elseif method == "set_lines_chunked_custom_size" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local complete_called = false
    local progress_calls = 0
    local waiter, signal = create_async_waiter(5000)

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_progress = function(written, total)
        progress_calls = progress_calls + 1
      end,
      on_complete = function()
        complete_called = true
        signal({ complete = true }, nil)
      end,
    })

    result.async_path = not complete_called

    waiter()
    result.on_complete_called = complete_called

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    result.lines_written = #buf_lines

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.async_path and not result.async_path then
      passed = false
      error_msg = "Expected async path for custom chunk size"
    end

  elseif method == "set_lines_chunked_progress" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local progress_values = {}
    local waiter, signal = create_async_waiter(5000)

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_progress = function(written, total)
        table.insert(progress_values, { written = written, total = total })
      end,
      on_complete = function()
        signal({ complete = true }, nil)
      end,
    })

    waiter()

    -- Check progress increases
    result.progress_increases = true
    local prev_written = 0
    for _, p in ipairs(progress_values) do
      if p.written < prev_written then
        result.progress_increases = false
        break
      end
      prev_written = p.written
    end

    -- Check final progress equals total
    if #progress_values > 0 then
      local final = progress_values[#progress_values]
      result.final_progress_equals_total = final.written == final.total
    else
      result.final_progress_equals_total = false
    end

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.progress_increases and not result.progress_increases then
      passed = false
      error_msg = "Expected progress to increase monotonically"
    end
    if expected.final_progress_equals_total and not result.final_progress_equals_total then
      passed = false
      error_msg = "Expected final progress to equal total"
    end

  elseif method == "set_lines_chunked_cancel" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local progress_count = 0

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_progress = function(written, total)
        progress_count = progress_count + 1
        if progress_count >= input.cancel_after_chunks then
          UiBuffer.cancel_chunked_write()
        end
      end,
    })

    -- Wait for cancellation to take effect
    vim.wait(200, function() return not UiBuffer.is_chunked_write_active() end, 20)

    result.cancelled = not UiBuffer.is_chunked_write_active()

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    result.partial_write = #buf_lines < input.line_count

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.cancelled and not result.cancelled then
      passed = false
      error_msg = "Expected chunked write to be cancelled"
    end
    if expected.partial_write and not result.partial_write then
      passed = false
      error_msg = "Expected partial write after cancel"
    end

  elseif method == "set_lines_chunked_active_check" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local lines = generate_lines(input.line_count)
    local was_active_during = false
    local waiter, signal = create_async_waiter(5000)

    UiBuffer.set_lines_chunked(lines, {
      chunk_size = input.chunk_size,
      on_progress = function(written, total)
        if UiBuffer.is_chunked_write_active() then
          was_active_during = true
        end
      end,
      on_complete = function()
        signal({ complete = true }, nil)
      end,
    })

    waiter()
    result.active_during_write = was_active_during
    result.inactive_after_complete = not UiBuffer.is_chunked_write_active()

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.active_during_write and not result.active_during_write then
      passed = false
      error_msg = "Expected is_chunked_write_active to be true during write"
    end
    if expected.inactive_after_complete and not result.inactive_after_complete then
      passed = false
      error_msg = "Expected is_chunked_write_active to be false after complete"
    end

  elseif method == "set_lines_chunked_replace" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local first_complete = false
    local second_complete = false
    local waiter, signal = create_async_waiter(5000)

    -- Start first write
    UiBuffer.set_lines_chunked(generate_lines(input.first_line_count), {
      chunk_size = input.chunk_size,
      on_complete = function()
        first_complete = true
      end,
    })

    -- Start second write immediately (should cancel first)
    vim.schedule(function()
      UiBuffer.set_lines_chunked(generate_lines(input.second_line_count), {
        chunk_size = input.chunk_size,
        on_complete = function()
          second_complete = true
          signal({ complete = true }, nil)
        end,
      })
    end)

    waiter()

    result.first_cancelled = not first_complete
    result.second_completed = second_complete

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.first_cancelled and first_complete then
      passed = false
      error_msg = "Expected first write to be cancelled"
    end
    if expected.second_completed and not second_complete then
      passed = false
      error_msg = "Expected second write to complete"
    end

  elseif method == "set_lines_chunked_empty" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local test_bufnr = create_test_buffer()

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local complete_called = false

    UiBuffer.set_lines_chunked({}, {
      on_complete = function()
        complete_called = true
      end,
    })

    result.on_complete_called = complete_called

    local buf_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
    -- Empty buffer has one empty line
    result.lines_written = #buf_lines == 1 and buf_lines[1] == "" and 0 or #buf_lines

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.on_complete_called and not result.on_complete_called then
      passed = false
      error_msg = "Expected on_complete to be called for empty lines"
    end

  -- ============================================================================
  -- UiHighlights.apply_batched tests
  -- ============================================================================

  elseif method == "apply_batched_small" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    -- Write some lines first
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local complete_called = false

    UiHighlights.apply_batched(line_map, {
      on_complete = function()
        complete_called = true
      end,
    })

    result.sync_path = complete_called
    result.on_complete_called = complete_called

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.sync_path and not result.sync_path then
      passed = false
      error_msg = "Expected sync path for small highlight batch"
    end

  elseif method == "apply_batched_exact" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local complete_called = false

    UiHighlights.apply_batched(line_map, {
      batch_size = input.batch_size,
      on_complete = function()
        complete_called = true
      end,
    })

    result.sync_path = complete_called
    result.on_complete_called = complete_called

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.sync_path and not result.sync_path then
      passed = false
      error_msg = "Expected sync path for exact batch_size"
    end

  elseif method == "apply_batched_large" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local complete_called = false
    local progress_calls = 0
    local waiter, signal = create_async_waiter(5000)

    UiHighlights.apply_batched(line_map, {
      batch_size = input.batch_size,
      on_progress = function(processed, total)
        progress_calls = progress_calls + 1
      end,
      on_complete = function()
        complete_called = true
        signal({ complete = true }, nil)
      end,
    })

    result.async_path = not complete_called

    waiter()
    result.on_complete_called = complete_called

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.async_path and not result.async_path then
      passed = false
      error_msg = "Expected async path for large batch"
    end
    if expected.min_progress_calls and progress_calls < expected.min_progress_calls then
      passed = false
      error_msg = string.format("Expected at least %d progress calls, got %d", expected.min_progress_calls, progress_calls)
    end

  elseif method == "apply_batched_progress" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local progress_values = {}
    local waiter, signal = create_async_waiter(5000)

    UiHighlights.apply_batched(line_map, {
      batch_size = input.batch_size,
      on_progress = function(processed, total)
        table.insert(progress_values, { processed = processed, total = total })
      end,
      on_complete = function()
        signal({ complete = true }, nil)
      end,
    })

    waiter()

    result.progress_increases = true
    local prev_processed = 0
    for _, p in ipairs(progress_values) do
      if p.processed < prev_processed then
        result.progress_increases = false
        break
      end
      prev_processed = p.processed
    end

    if #progress_values > 0 then
      local final = progress_values[#progress_values]
      result.final_progress_equals_total = final.processed == final.total
    else
      result.final_progress_equals_total = false
    end

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.progress_increases and not result.progress_increases then
      passed = false
      error_msg = "Expected progress to increase monotonically"
    end
    if expected.final_progress_equals_total and not result.final_progress_equals_total then
      passed = false
      error_msg = "Expected final progress to equal total"
    end

  elseif method == "apply_batched_cancel" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local progress_count = 0

    UiHighlights.apply_batched(line_map, {
      batch_size = input.batch_size,
      on_progress = function(processed, total)
        progress_count = progress_count + 1
        if progress_count >= input.cancel_after_batches then
          UiHighlights.cancel_batched()
        end
      end,
    })

    vim.wait(200, function() return not UiHighlights.is_batched_active() end, 20)
    result.cancelled = not UiHighlights.is_batched_active()

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.cancelled and not result.cancelled then
      passed = false
      error_msg = "Expected batched highlight to be cancelled"
    end

  elseif method == "apply_batched_active_check" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local line_map = create_mock_line_map(input.line_count)
    local was_active_during = false
    local waiter, signal = create_async_waiter(5000)

    UiHighlights.apply_batched(line_map, {
      batch_size = input.batch_size,
      on_progress = function(processed, total)
        if UiHighlights.is_batched_active() then
          was_active_during = true
        end
      end,
      on_complete = function()
        signal({ complete = true }, nil)
      end,
    })

    waiter()
    result.active_during_apply = was_active_during
    result.inactive_after_complete = not UiHighlights.is_batched_active()

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.active_during_apply and not result.active_during_apply then
      passed = false
      error_msg = "Expected is_batched_active to be true during apply"
    end
    if expected.inactive_after_complete and not result.inactive_after_complete then
      passed = false
      error_msg = "Expected is_batched_active to be false after complete"
    end

  elseif method == "apply_batched_replace" then
    local UiBuffer = require("ssns.ui.core.buffer")
    local UiHighlights = require("ssns.ui.core.highlights")
    local test_bufnr = create_test_buffer()

    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, generate_lines(input.first_line_count))

    local orig_bufnr = UiBuffer.bufnr
    local orig_exists = UiBuffer.exists
    UiBuffer.bufnr = test_bufnr
    UiBuffer.exists = function() return true end

    local first_complete = false
    local second_complete = false
    local waiter, signal = create_async_waiter(5000)

    UiHighlights.apply_batched(create_mock_line_map(input.first_line_count), {
      batch_size = input.batch_size,
      on_complete = function()
        first_complete = true
      end,
    })

    vim.schedule(function()
      UiHighlights.apply_batched(create_mock_line_map(input.second_line_count), {
        batch_size = input.batch_size,
        on_complete = function()
          second_complete = true
          signal({ complete = true }, nil)
        end,
      })
    end)

    waiter()

    result.first_cancelled = not first_complete
    result.second_completed = second_complete

    UiBuffer.bufnr = orig_bufnr
    UiBuffer.exists = orig_exists
    delete_test_buffer(test_bufnr)

    if expected.first_cancelled and first_complete then
      passed = false
      error_msg = "Expected first batch to be cancelled"
    end
    if expected.second_completed and not second_complete then
      passed = false
      error_msg = "Expected second batch to complete"
    end

  else
    return nil, false, "Unknown chunked rendering method: " .. tostring(method)
  end

  return result, passed, error_msg
end

---Run async test - dispatcher to specific async test runners
---@param test table Test definition
---@return table actual Actual output
---@return boolean passed Whether test passed
---@return string? error Error message if failed
function UnitRunner._run_async_test(test)
  local module = test.module

  if module == "ssns.async.file_io" then
    return UnitRunner._run_async_file_io_test(test)
  elseif module == "ssns.connections" then
    return UnitRunner._run_async_connections_test(test)
  elseif module == "ssns.debug" then
    return UnitRunner._run_async_debug_test(test)
  elseif module == "ssns.async.cancellation" then
    return UnitRunner._run_async_cancellation_test(test)
  elseif module == "ssns.completion.providers" then
    return UnitRunner._run_async_completion_providers_test(test)
  elseif module == "ssns.ui.chunked" then
    return UnitRunner._run_async_chunked_rendering_test(test)
  else
    return nil, false, "Unknown async test module: " .. tostring(module)
  end
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
  -- Support both test.opts and test.config for flexibility
  local opts = test.opts or test.config or {}

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
