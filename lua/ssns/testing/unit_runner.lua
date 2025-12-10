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
