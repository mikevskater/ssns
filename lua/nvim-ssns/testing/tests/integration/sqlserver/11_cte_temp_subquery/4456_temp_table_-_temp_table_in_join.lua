-- Test 4456: Temp table - temp table in JOIN
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4456,
  description = "Temp table - temp table in JOIN",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempDept (DeptID INT, DeptName VARCHAR(100))
SELECT * FROM Employees e JOIN █]],
  expected = {
    items = {
      includes = {
        "#TempDept",
        "Departments",
      },
    },
    type = "table",
  },
}
