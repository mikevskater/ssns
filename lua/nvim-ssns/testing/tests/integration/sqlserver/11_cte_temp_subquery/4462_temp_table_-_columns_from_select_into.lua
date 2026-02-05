-- Test 4462: Temp table - columns from SELECT INTO
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4462,
  description = "Temp table - columns from SELECT INTO",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT EmployeeID, FirstName, DepartmentID INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
  expected = {
    items = {
      excludes = {
        "LastName",
        "Salary",
      },
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
