---Database structure constants for integration tests
---Provides structured access to all database objects for test includes/excludes
---@module ssns.testing.db_constants
local M = {}

-- =============================================================================
-- DATABASE NAMES
-- =============================================================================
M.databases = {
  "vim_dadbod_test",
  "TEST",
  "Branch_Prod",
}

-- =============================================================================
-- VIM_DADBOD_TEST DATABASE
-- =============================================================================
M.vim_dadbod_test = {
  name = "vim_dadbod_test",

  schemas = { "dbo", "hr" },

  dbo = {
    name = "dbo",

    tables = {
      "Employees",
      "Departments",
      "Projects",
      "Customers",
      "Orders",
      "Products",
      "Regions",
      "Countries",
    },

    views = {
      "vw_ActiveEmployees",
      "vw_DepartmentSummary",
      "vw_ProjectStatus",
    },

    procedures = {
      "usp_GetEmployeesByDepartment",
      "usp_InsertEmployee",
    },

    -- Scalar functions (not usable in FROM clause)
    scalar_functions = {
      "fn_CalculateYearsOfService",
      "fn_GetEmployeeFullName",
    },

    -- Table-valued functions (usable in FROM clause)
    table_functions = {
      "fn_GetEmployeesBySalaryRange",
      "GetCustomerOrders",
    },

    synonyms = {
      "syn_ActiveEmployees",
      "syn_Depts",
      "syn_Employees",
      "syn_HRBenefits",
    },
  },

  hr = {
    name = "hr",

    tables = {
      "Benefits",
    },

    views = {},

    procedures = {},

    scalar_functions = {
      "fn_GetTotalBenefitCost",
    },

    table_functions = {},

    synonyms = {},
  },
}

-- =============================================================================
-- TEST DATABASE
-- =============================================================================
M.TEST = {
  name = "TEST",

  schemas = { "dbo" },

  dbo = {
    name = "dbo",

    tables = {
      "Records",
    },

    views = {},

    procedures = {},

    scalar_functions = {},

    table_functions = {},

    synonyms = {
      "syn_MainEmployees",
    },
  },
}

-- =============================================================================
-- BRANCH_PROD DATABASE
-- =============================================================================
M.Branch_Prod = {
  name = "Branch_Prod",

  schemas = { "dbo" },

  dbo = {
    name = "dbo",

    tables = {
      "central_division",
      "eastern_division",
      "western_division",
      "division_metrics",
    },

    views = {
      "vw_all_divisions",
    },

    procedures = {
      "usp_GetDivisionMetrics",
    },

    scalar_functions = {},

    table_functions = {},

    synonyms = {},
  },
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

---Merge multiple arrays into one
---@param ... table[] Arrays to merge
---@return table merged Combined array
local function merge(...)
  local result = {}
  for _, arr in ipairs({...}) do
    if arr then
      for _, v in ipairs(arr) do
        table.insert(result, v)
      end
    end
  end
  return result
end

---Get all objects from a schema (tables, views, synonyms, table functions)
---These are the objects that appear in FROM/JOIN completion
---@param schema table Schema object (e.g., M.vim_dadbod_test.dbo)
---@return table objects All queryable objects from the schema
function M.get_from_objects(schema)
  return merge(
    schema.tables,
    schema.views,
    schema.synonyms,
    schema.table_functions
  )
end

---Get all objects from a schema (tables, views, synonyms, ALL functions, procedures)
---@param schema table Schema object
---@return table objects All objects from the schema
function M.get_all_objects(schema)
  return merge(
    schema.tables,
    schema.views,
    schema.synonyms,
    schema.table_functions,
    schema.scalar_functions,
    schema.procedures
  )
end

---Get all schemas from a database
---@param database table Database object (e.g., M.vim_dadbod_test)
---@return table schemas Schema names
function M.get_schemas(database)
  return database.schemas
end

---Get all FROM-compatible objects from a database (across all schemas)
---@param database table Database object
---@return table objects All queryable objects from all schemas
function M.get_all_from_objects(database)
  local result = {}
  for _, schema_name in ipairs(database.schemas) do
    local schema = database[schema_name]
    if schema then
      for _, obj in ipairs(M.get_from_objects(schema)) do
        table.insert(result, obj)
      end
    end
  end
  return result
end

-- =============================================================================
-- PRE-BUILT COLLECTIONS FOR COMMON TEST SCENARIOS
-- =============================================================================

---Objects that should appear when completing "SELECT * FROM dbo.█" in vim_dadbod_test
M.vim_dadbod_test_dbo_from_objects = M.get_from_objects(M.vim_dadbod_test.dbo)

---Objects that should appear when completing "SELECT * FROM hr.█" in vim_dadbod_test
M.vim_dadbod_test_hr_from_objects = M.get_from_objects(M.vim_dadbod_test.hr)

---Objects that should appear when completing "SELECT * FROM dbo.█" in Branch_Prod
M.Branch_Prod_dbo_from_objects = M.get_from_objects(M.Branch_Prod.dbo)

---Objects that should appear when completing "SELECT * FROM dbo.█" in TEST
M.TEST_dbo_from_objects = M.get_from_objects(M.TEST.dbo)

-- =============================================================================
-- EXCLUSION LISTS FOR SCHEMA-QUALIFIED COMPLETION TESTS
-- =============================================================================

---Things that should NOT appear when completing schema-qualified tables
---Includes: databases, schemas, other schema objects, procedures, scalar functions
function M.get_dbo_excludes_for_vim_dadbod_test()
  return merge(
    -- Databases should not appear
    M.databases,
    -- Schemas should not appear
    M.vim_dadbod_test.schemas,
    -- Objects from hr schema should not appear
    M.get_all_objects(M.vim_dadbod_test.hr),
    -- Objects from other databases should not appear
    M.get_all_objects(M.Branch_Prod.dbo),
    M.get_all_objects(M.TEST.dbo)
  )
end

---Things that should NOT appear when completing hr schema in vim_dadbod_test
function M.get_hr_excludes_for_vim_dadbod_test()
  return merge(
    -- Databases should not appear
    M.databases,
    -- Schemas should not appear
    M.vim_dadbod_test.schemas,
    -- Objects from dbo schema should not appear
    M.get_all_objects(M.vim_dadbod_test.dbo),
    -- Objects from other databases should not appear
    M.get_all_objects(M.Branch_Prod.dbo),
    M.get_all_objects(M.TEST.dbo)
  )
end

---Things that should NOT appear when completing Branch_Prod.dbo.█
function M.get_Branch_Prod_dbo_excludes()
  return merge(
    -- Databases should not appear
    M.databases,
    -- Schemas should not appear
    M.Branch_Prod.schemas,
    -- Objects from vim_dadbod_test should not appear
    M.get_all_objects(M.vim_dadbod_test.dbo),
    M.get_all_objects(M.vim_dadbod_test.hr),
    -- Objects from TEST should not appear
    M.get_all_objects(M.TEST.dbo)
  )
end

---Things that should NOT appear when completing TEST.dbo.█
function M.get_TEST_dbo_excludes()
  return merge(
    -- Databases should not appear
    M.databases,
    -- Schemas should not appear
    M.TEST.schemas,
    -- Objects from vim_dadbod_test should not appear
    M.get_all_objects(M.vim_dadbod_test.dbo),
    M.get_all_objects(M.vim_dadbod_test.hr),
    -- Objects from Branch_Prod should not appear
    M.get_all_objects(M.Branch_Prod.dbo)
  )
end

return M
