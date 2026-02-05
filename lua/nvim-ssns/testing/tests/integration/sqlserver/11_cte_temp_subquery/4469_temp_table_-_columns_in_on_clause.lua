-- Test 4469: Temp table - columns in ON clause
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4469,
  description = "Temp table - columns in ON clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempDept (DeptID INT, DeptName VARCHAR(100))
SELECT * FROM Employees e JOIN #TempDept t ON e.DepartmentID = t.█]],
  expected = {
    items = {
      includes = {
        "DeptID",
      },
    },
    type = "column",
  },
}
