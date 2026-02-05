-- Test 4561: INSERT - OUTPUT INTO table
-- SKIPPED: OUTPUT INTO table completion not yet supported

return {
  number = 4561,
  description = "INSERT - OUTPUT INTO table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempIDs (ID INT)
INSERT INTO Employees (FirstName)
OUTPUT inserted.EmployeeID INTO █]],
  expected = {
    items = {
      includes = {
        "Projects",
        "#TempIDs",
      },
    },
    type = "table",
  },
}
