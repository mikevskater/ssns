-- Test 4439: CTE - CTE with DISTINCT

return {
  number = 4439,
  description = "CTE - CTE with DISTINCT",
  database = "vim_dadbod_test",
  query = [[WITH UniqueDepts AS (SELECT DISTINCT DepartmentID FROM Employees)
SELECT █ FROM UniqueDepts]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
      },
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
