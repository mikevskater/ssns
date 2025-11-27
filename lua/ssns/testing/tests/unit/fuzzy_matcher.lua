-- Test file: fuzzy_matcher.lua
-- IDs: 3701-3800
-- Tests: FuzzyMatcher utility module for column name matching
--
-- Test categories:
-- - 3701-3720: Normalization tests
-- - 3721-3750: Similarity score tests
-- - 3751-3770: Match threshold tests
-- - 3771-3785: Find matches tests
-- - 3786-3800: Column matching tests

return {
  -- ============================================================================
  -- NORMALIZATION TESTS (3701-3720)
  -- ============================================================================

  {
    id = 3701,
    type = "fuzzy_matcher",
    name = "Normalize removes underscores",
    input = { s = "Employee_ID" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3702,
    type = "fuzzy_matcher",
    name = "Normalize lowercase conversion",
    input = { s = "EMPLOYEEID" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3703,
    type = "fuzzy_matcher",
    name = "Normalize removes FK prefix",
    input = { s = "FKDepartmentID" },
    expected = {
      normalized = "departmentid",
    },
  },

  {
    id = 3704,
    type = "fuzzy_matcher",
    name = "Normalize removes PK prefix",
    input = { s = "PKEmployeeID" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3705,
    type = "fuzzy_matcher",
    name = "Normalize removes multiple underscores",
    input = { s = "First___Name___ID" },
    expected = {
      normalized = "firstnameid",
    },
  },

  {
    id = 3706,
    type = "fuzzy_matcher",
    name = "Normalize preserves numbers",
    input = { s = "Employee123ID" },
    expected = {
      normalized = "employee123id",
    },
  },

  {
    id = 3707,
    type = "fuzzy_matcher",
    name = "Normalize empty string",
    input = { s = "" },
    expected = {
      normalized = "",
    },
  },

  {
    id = 3708,
    type = "fuzzy_matcher",
    name = "Normalize nil input",
    input = { s = nil },
    expected = {
      normalized = "",
    },
  },

  {
    id = 3709,
    type = "fuzzy_matcher",
    name = "Normalize all uppercase with underscores",
    input = { s = "EMPLOYEE_ID_NUMBER" },
    expected = {
      normalized = "employeeidnumber",
    },
  },

  {
    id = 3710,
    type = "fuzzy_matcher",
    name = "Normalize CamelCase to lowercase",
    input = { s = "EmployeeIDNumber" },
    expected = {
      normalized = "employeeidnumber",
    },
  },

  {
    id = 3711,
    type = "fuzzy_matcher",
    name = "Normalize mixed case with underscores",
    input = { s = "Employee_Id_Number" },
    expected = {
      normalized = "employeeidnumber",
    },
  },

  {
    id = 3712,
    type = "fuzzy_matcher",
    name = "Normalize FK prefix case-insensitive",
    input = { s = "fkDepartmentID" },
    expected = {
      normalized = "departmentid",
    },
  },

  {
    id = 3713,
    type = "fuzzy_matcher",
    name = "Normalize PK prefix case-insensitive",
    input = { s = "pkEmployeeID" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3714,
    type = "fuzzy_matcher",
    name = "Normalize preserves alphanumeric only",
    input = { s = "Employee-ID#123" },
    expected = {
      normalized = "employeeid123",
    },
  },

  {
    id = 3715,
    type = "fuzzy_matcher",
    name = "Normalize handles numbers at start",
    input = { s = "123EmployeeID" },
    expected = {
      normalized = "123employeeid",
    },
  },

  {
    id = 3716,
    type = "fuzzy_matcher",
    name = "Normalize handles only underscores",
    input = { s = "___" },
    expected = {
      normalized = "",
    },
  },

  {
    id = 3717,
    type = "fuzzy_matcher",
    name = "Normalize removes leading underscores",
    input = { s = "__EmployeeID" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3718,
    type = "fuzzy_matcher",
    name = "Normalize removes trailing underscores",
    input = { s = "EmployeeID__" },
    expected = {
      normalized = "employeeid",
    },
  },

  {
    id = 3719,
    type = "fuzzy_matcher",
    name = "Normalize FK prefix with underscore",
    input = { s = "FK_DepartmentID" },
    expected = {
      normalized = "departmentid",
    },
  },

  {
    id = 3720,
    type = "fuzzy_matcher",
    name = "Normalize PK prefix with underscore",
    input = { s = "PK_EmployeeID" },
    expected = {
      normalized = "employeeid",
    },
  },

  -- ============================================================================
  -- SIMILARITY SCORE TESTS (3721-3750)
  -- ============================================================================

  {
    id = 3721,
    type = "fuzzy_matcher",
    name = "Similarity exact match returns 1.0",
    input = { s1 = "EmployeeID", s2 = "EmployeeID" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3722,
    type = "fuzzy_matcher",
    name = "Similarity completely different returns low score",
    input = { s1 = "EmployeeID", s2 = "DepartmentName" },
    expected = {
      score_less_than = 0.5,
    },
  },

  {
    id = 3723,
    type = "fuzzy_matcher",
    name = "Similarity one character different",
    input = { s1 = "EmployeeID", s2 = "EmployeID" },
    expected = {
      score_greater_than = 0.9,
    },
  },

  {
    id = 3724,
    type = "fuzzy_matcher",
    name = "Similarity two characters different",
    input = { s1 = "EmployeeID", s2 = "EmploeeID" },
    expected = {
      score_greater_than = 0.8,
    },
  },

  {
    id = 3725,
    type = "fuzzy_matcher",
    name = "Similarity transposition detected",
    input = { s1 = "EmployeeID", s2 = "EmployeIeD" },
    expected = {
      score_greater_than = 0.85,
    },
  },

  {
    id = 3726,
    type = "fuzzy_matcher",
    name = "Similarity length difference penalty",
    input = { s1 = "ID", s2 = "EmployeeID" },
    expected = {
      score_less_than = 0.5,
    },
  },

  {
    id = 3727,
    type = "fuzzy_matcher",
    name = "Similarity empty vs non-empty",
    input = { s1 = "", s2 = "EmployeeID" },
    expected = {
      score = 0.0,
    },
  },

  {
    id = 3728,
    type = "fuzzy_matcher",
    name = "Similarity case differences handled by normalize",
    input = { s1 = "EMPLOYEEID", s2 = "employeeid" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3729,
    type = "fuzzy_matcher",
    name = "Similarity underscore differences handled",
    input = { s1 = "Employee_ID", s2 = "EmployeeID" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3730,
    type = "fuzzy_matcher",
    name = "Similarity with FK prefix vs without",
    input = { s1 = "FKDepartmentID", s2 = "DepartmentID" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3731,
    type = "fuzzy_matcher",
    name = "Similarity with PK prefix vs without",
    input = { s1 = "PKEmployeeID", s2 = "EmployeeID" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3732,
    type = "fuzzy_matcher",
    name = "Similarity common prefix high score",
    input = { s1 = "EmployeeID", s2 = "EmployeeName" },
    expected = {
      score_greater_than = 0.6,
    },
  },

  {
    id = 3733,
    type = "fuzzy_matcher",
    name = "Similarity common suffix high score",
    input = { s1 = "EmployeeID", s2 = "DepartmentID" },
    expected = {
      score_greater_than = 0.3,
    },
  },

  {
    id = 3734,
    type = "fuzzy_matcher",
    name = "Similarity nil first input",
    input = { s1 = nil, s2 = "EmployeeID" },
    expected = {
      score = 0.0,
    },
  },

  {
    id = 3735,
    type = "fuzzy_matcher",
    name = "Similarity nil second input",
    input = { s1 = "EmployeeID", s2 = nil },
    expected = {
      score = 0.0,
    },
  },

  {
    id = 3736,
    type = "fuzzy_matcher",
    name = "Similarity both nil inputs",
    input = { s1 = nil, s2 = nil },
    expected = {
      score = 0.0,
    },
  },

  {
    id = 3737,
    type = "fuzzy_matcher",
    name = "Similarity long strings with minor differences",
    input = { s1 = "VeryLongEmployeeIdentificationNumber", s2 = "VeryLongEmployeeIdentificationNumbe" },
    expected = {
      score_greater_than = 0.95,
    },
  },

  {
    id = 3738,
    type = "fuzzy_matcher",
    name = "Similarity short strings exact match",
    input = { s1 = "ID", s2 = "ID" },
    expected = {
      score = 1.0,
    },
  },

  {
    id = 3739,
    type = "fuzzy_matcher",
    name = "Similarity short strings one char diff",
    input = { s1 = "ID", s2 = "Id" },
    expected = {
      score = 1.0, -- Normalized to same
    },
  },

  {
    id = 3740,
    type = "fuzzy_matcher",
    name = "Similarity abbreviation vs full (Emp vs Employee)",
    input = { s1 = "EmpID", s2 = "EmployeeID" },
    expected = {
      score_greater_than = 0.6,
    },
  },

  {
    id = 3741,
    type = "fuzzy_matcher",
    name = "Similarity abbreviation vs full (Dept vs Department)",
    input = { s1 = "DeptID", s2 = "DepartmentID" },
    expected = {
      score_greater_than = 0.6,
    },
  },

  {
    id = 3742,
    type = "fuzzy_matcher",
    name = "Similarity number suffix difference",
    input = { s1 = "EmployeeID1", s2 = "EmployeeID" },
    expected = {
      score_greater_than = 0.9,
    },
  },

  {
    id = 3743,
    type = "fuzzy_matcher",
    name = "Similarity different number suffixes",
    input = { s1 = "EmployeeID1", s2 = "EmployeeID2" },
    expected = {
      score_greater_than = 0.9,
    },
  },

  {
    id = 3744,
    type = "fuzzy_matcher",
    name = "Similarity plural vs singular",
    input = { s1 = "Employees", s2 = "Employee" },
    expected = {
      score_greater_than = 0.9,
    },
  },

  {
    id = 3745,
    type = "fuzzy_matcher",
    name = "Similarity substring match",
    input = { s1 = "Employee", s2 = "EmployeeID" },
    expected = {
      score_greater_than = 0.7,
    },
  },

  {
    id = 3746,
    type = "fuzzy_matcher",
    name = "Similarity reversed strings low score",
    input = { s1 = "EmployeeID", s2 = "DIeeyolpmE" },
    expected = {
      score_less_than = 0.5,
    },
  },

  {
    id = 3747,
    type = "fuzzy_matcher",
    name = "Similarity single character vs long string",
    input = { s1 = "E", s2 = "EmployeeID" },
    expected = {
      score_less_than = 0.3,
    },
  },

  {
    id = 3748,
    type = "fuzzy_matcher",
    name = "Similarity repeated characters",
    input = { s1 = "EmployeeeeID", s2 = "EmployeeID" },
    expected = {
      score_greater_than = 0.85,
    },
  },

  {
    id = 3749,
    type = "fuzzy_matcher",
    name = "Similarity missing middle characters",
    input = { s1 = "EmplID", s2 = "EmployeeID" },
    expected = {
      score_greater_than = 0.6,
    },
  },

  {
    id = 3750,
    type = "fuzzy_matcher",
    name = "Similarity with special chars removed",
    input = { s1 = "Employee-ID", s2 = "Employee_ID" },
    expected = {
      score = 1.0, -- Both normalized to employeeid
    },
  },

  -- ============================================================================
  -- MATCH THRESHOLD TESTS (3751-3770)
  -- ============================================================================

  {
    id = 3751,
    type = "fuzzy_matcher",
    name = "Match exact match with default threshold",
    input = { s1 = "EmployeeID", s2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
      score = 1.0,
    },
  },

  {
    id = 3752,
    type = "fuzzy_matcher",
    name = "Match 90% similarity passes 0.85 threshold",
    input = { s1 = "EmployeeID", s2 = "Employee_ID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3753,
    type = "fuzzy_matcher",
    name = "Match low similarity fails 0.85 threshold",
    input = { s1 = "EmployeeID", s2 = "DepartmentName", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3754,
    type = "fuzzy_matcher",
    name = "Match custom threshold 0.9 strict",
    input = { s1 = "EmployeeID", s2 = "EmployeID", threshold = 0.9 },
    expected = {
      is_match = true, -- Should still pass
    },
  },

  {
    id = 3755,
    type = "fuzzy_matcher",
    name = "Match custom threshold 0.7 lenient",
    input = { s1 = "EmpID", s2 = "EmployeeID", threshold = 0.7 },
    expected = {
      is_match = false, -- May not pass even with lenient threshold
    },
  },

  {
    id = 3756,
    type = "fuzzy_matcher",
    name = "Match threshold edge case exactly at threshold",
    input = { s1 = "Test", s2 = "Test", threshold = 1.0 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3757,
    type = "fuzzy_matcher",
    name = "Match threshold 0.0 accepts everything",
    input = { s1 = "EmployeeID", s2 = "xyz", threshold = 0.0 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3758,
    type = "fuzzy_matcher",
    name = "Match threshold 1.0 requires exact",
    input = { s1 = "EmployeeID", s2 = "Employee_ID", threshold = 1.0 },
    expected = {
      is_match = true, -- Normalized they're exact
    },
  },

  {
    id = 3759,
    type = "fuzzy_matcher",
    name = "Match nil threshold uses default 0.85",
    input = { s1 = "EmployeeID", s2 = "EmployeeID", threshold = nil },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3760,
    type = "fuzzy_matcher",
    name = "Match score returned with match result",
    input = { s1 = "EmployeeID", s2 = "Employee_ID", threshold = 0.85 },
    expected = {
      has_score = true,
    },
  },

  {
    id = 3761,
    type = "fuzzy_matcher",
    name = "Match FK prefix normalized matches",
    input = { s1 = "FKDepartmentID", s2 = "DepartmentID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3762,
    type = "fuzzy_matcher",
    name = "Match PK prefix normalized matches",
    input = { s1 = "PKEmployeeID", s2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3763,
    type = "fuzzy_matcher",
    name = "Match case insensitive with threshold",
    input = { s1 = "EMPLOYEEID", s2 = "employeeid", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3764,
    type = "fuzzy_matcher",
    name = "Match empty strings don't match",
    input = { s1 = "", s2 = "", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3765,
    type = "fuzzy_matcher",
    name = "Match nil inputs don't match",
    input = { s1 = nil, s2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3766,
    type = "fuzzy_matcher",
    name = "Match single char difference passes high threshold",
    input = { s1 = "EmployeeID", s2 = "EmployeID", threshold = 0.9 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3767,
    type = "fuzzy_matcher",
    name = "Match abbreviation fails strict threshold",
    input = { s1 = "EmpID", s2 = "EmployeeID", threshold = 0.95 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3768,
    type = "fuzzy_matcher",
    name = "Match number suffix with threshold",
    input = { s1 = "EmployeeID1", s2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3769,
    type = "fuzzy_matcher",
    name = "Match plural vs singular with threshold",
    input = { s1 = "Employees", s2 = "Employee", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3770,
    type = "fuzzy_matcher",
    name = "Match underscore variants with threshold",
    input = { s1 = "First_Name", s2 = "FirstName", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  -- ============================================================================
  -- FIND MATCHES TESTS (3771-3785)
  -- ============================================================================

  {
    id = 3771,
    type = "fuzzy_matcher",
    name = "Find matches single match in list",
    input = {
      needle = "EmployeeID",
      haystack = { "DepartmentID", "EmployeeID", "FirstName" },
      threshold = 0.85,
    },
    expected = {
      match_count = 1,
      first_match = "EmployeeID",
    },
  },

  {
    id = 3772,
    type = "fuzzy_matcher",
    name = "Find matches multiple matches sorted by score",
    input = {
      needle = "EmployeeID",
      haystack = { "EmployeeID", "Employee_ID", "EmployeID", "EmpID" },
      threshold = 0.85,
    },
    expected = {
      match_count_at_least = 2,
      sorted_by_score = true,
    },
  },

  {
    id = 3773,
    type = "fuzzy_matcher",
    name = "Find matches no matches found",
    input = {
      needle = "EmployeeID",
      haystack = { "DepartmentName", "FirstName", "LastName" },
      threshold = 0.85,
    },
    expected = {
      match_count = 0,
    },
  },

  {
    id = 3774,
    type = "fuzzy_matcher",
    name = "Find matches empty haystack",
    input = {
      needle = "EmployeeID",
      haystack = {},
      threshold = 0.85,
    },
    expected = {
      match_count = 0,
    },
  },

  {
    id = 3775,
    type = "fuzzy_matcher",
    name = "Find matches all items match",
    input = {
      needle = "EmployeeID",
      haystack = { "EmployeeID", "Employee_ID", "EMPLOYEEID" },
      threshold = 0.85,
    },
    expected = {
      match_count = 3,
    },
  },

  {
    id = 3776,
    type = "fuzzy_matcher",
    name = "Find matches custom threshold lenient",
    input = {
      needle = "EmpID",
      haystack = { "EmployeeID", "DepartmentID", "ID" },
      threshold = 0.6,
    },
    expected = {
      match_count_at_least = 1,
    },
  },

  {
    id = 3777,
    type = "fuzzy_matcher",
    name = "Find matches FK prefix variants",
    input = {
      needle = "DepartmentID",
      haystack = { "FKDepartmentID", "FK_DepartmentID", "DepartmentID" },
      threshold = 0.85,
    },
    expected = {
      match_count = 3,
    },
  },

  {
    id = 3778,
    type = "fuzzy_matcher",
    name = "Find matches returns scores",
    input = {
      needle = "EmployeeID",
      haystack = { "EmployeeID", "EmployeID" },
      threshold = 0.85,
    },
    expected = {
      all_have_scores = true,
    },
  },

  {
    id = 3779,
    type = "fuzzy_matcher",
    name = "Find matches score descending order",
    input = {
      needle = "EmployeeID",
      haystack = { "EmpID", "EmployeID", "EmployeeID" },
      threshold = 0.7,
    },
    expected = {
      first_has_highest_score = true,
    },
  },

  {
    id = 3780,
    type = "fuzzy_matcher",
    name = "Find matches nil needle",
    input = {
      needle = nil,
      haystack = { "EmployeeID", "DepartmentID" },
      threshold = 0.85,
    },
    expected = {
      match_count = 0,
    },
  },

  {
    id = 3781,
    type = "fuzzy_matcher",
    name = "Find matches nil haystack",
    input = {
      needle = "EmployeeID",
      haystack = nil,
      threshold = 0.85,
    },
    expected = {
      match_count = 0,
    },
  },

  {
    id = 3782,
    type = "fuzzy_matcher",
    name = "Find matches with duplicates in haystack",
    input = {
      needle = "EmployeeID",
      haystack = { "EmployeeID", "EmployeeID", "DepartmentID" },
      threshold = 0.85,
    },
    expected = {
      match_count = 2, -- Both duplicates matched
    },
  },

  {
    id = 3783,
    type = "fuzzy_matcher",
    name = "Find matches long haystack performance",
    input = {
      needle = "EmployeeID",
      haystack = {
        "ID1", "ID2", "ID3", "EmployeeID", "ID4", "ID5",
        "ID6", "ID7", "ID8", "ID9", "ID10",
      },
      threshold = 0.85,
    },
    expected = {
      match_count_at_least = 1,
    },
  },

  {
    id = 3784,
    type = "fuzzy_matcher",
    name = "Find matches case variations",
    input = {
      needle = "EmployeeID",
      haystack = { "EMPLOYEEID", "employeeid", "EmployeeId" },
      threshold = 0.85,
    },
    expected = {
      match_count = 3,
    },
  },

  {
    id = 3785,
    type = "fuzzy_matcher",
    name = "Find matches underscore variations",
    input = {
      needle = "EmployeeID",
      haystack = { "Employee_ID", "Employee__ID", "EmployeeID" },
      threshold = 0.85,
    },
    expected = {
      match_count = 3,
    },
  },

  -- ============================================================================
  -- COLUMN MATCHING TESTS (3786-3800)
  -- ============================================================================

  {
    id = 3786,
    type = "fuzzy_matcher",
    name = "Column match exact match",
    input = { col1 = "EmployeeID", col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
      score = 1.0,
    },
  },

  {
    id = 3787,
    type = "fuzzy_matcher",
    name = "Column match case insensitive",
    input = { col1 = "EMPLOYEEID", col2 = "employeeid", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3788,
    type = "fuzzy_matcher",
    name = "Column match underscore variant",
    input = { col1 = "Employee_ID", col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3789,
    type = "fuzzy_matcher",
    name = "Column match FK prefix variant",
    input = { col1 = "FKDepartmentID", col2 = "DepartmentID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3790,
    type = "fuzzy_matcher",
    name = "Column match similar column names",
    input = { col1 = "EmpID", col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = false, -- Too different
    },
  },

  {
    id = 3791,
    type = "fuzzy_matcher",
    name = "Column match different columns",
    input = { col1 = "EmployeeID", col2 = "DepartmentID", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3792,
    type = "fuzzy_matcher",
    name = "Column match ID vs Identifier",
    input = { col1 = "ID", col2 = "Identifier", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3793,
    type = "fuzzy_matcher",
    name = "Column match numeric suffix handling",
    input = { col1 = "EmployeeID1", col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3794,
    type = "fuzzy_matcher",
    name = "Column match self-join scenario ManagerID vs EmployeeID",
    input = { col1 = "ManagerID", col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3795,
    type = "fuzzy_matcher",
    name = "Column match plural handling",
    input = { col1 = "Employees", col2 = "Employee", threshold = 0.85 },
    expected = {
      is_match = true,
    },
  },

  {
    id = 3796,
    type = "fuzzy_matcher",
    name = "Column match with lenient threshold",
    input = { col1 = "DeptID", col2 = "DepartmentID", threshold = 0.7 },
    expected = {
      is_match = false, -- Still may not pass
    },
  },

  {
    id = 3797,
    type = "fuzzy_matcher",
    name = "Column match with strict threshold",
    input = { col1 = "Employee_ID", col2 = "EmployeeID", threshold = 0.95 },
    expected = {
      is_match = true, -- Normalized exact match
    },
  },

  {
    id = 3798,
    type = "fuzzy_matcher",
    name = "Column match nil columns",
    input = { col1 = nil, col2 = "EmployeeID", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3799,
    type = "fuzzy_matcher",
    name = "Column match empty strings",
    input = { col1 = "", col2 = "", threshold = 0.85 },
    expected = {
      is_match = false,
    },
  },

  {
    id = 3800,
    type = "fuzzy_matcher",
    name = "Column match with special characters",
    input = { col1 = "Employee-ID", col2 = "Employee_ID", threshold = 0.85 },
    expected = {
      is_match = true, -- Both normalized to employeeid
    },
  },
}
