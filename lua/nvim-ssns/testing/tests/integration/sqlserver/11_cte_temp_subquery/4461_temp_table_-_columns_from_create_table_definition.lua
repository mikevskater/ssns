-- Test 4461: Temp table - columns from CREATE TABLE definition
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4461,
  description = "Temp table - columns from CREATE TABLE definition",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (EmployeeID INT, FirstName VARCHAR(50), LastName VARCHAR(50))
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
