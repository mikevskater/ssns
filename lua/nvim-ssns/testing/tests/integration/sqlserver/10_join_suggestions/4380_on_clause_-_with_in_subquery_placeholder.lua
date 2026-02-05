-- Test 4380: ON clause - column completion in IN subquery
-- Tests column completion in SELECT clause of subquery within ON clause

return {
  number = 4380,
  description = "ON clause - column completion in IN subquery",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID IN (SELECT █ FROM Departments)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
