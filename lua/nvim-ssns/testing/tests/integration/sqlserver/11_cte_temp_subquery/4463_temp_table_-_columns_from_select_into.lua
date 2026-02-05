-- Test 4463: Temp table - columns from SELECT * INTO
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4463,
  description = "Temp table - columns from SELECT * INTO",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
