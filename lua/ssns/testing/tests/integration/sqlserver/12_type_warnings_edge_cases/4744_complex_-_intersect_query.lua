-- Test 4744: Complex - INTERSECT query

return {
  number = 4744,
  description = "Complex - INTERSECT query",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID FROM Employees INTERSECT SELECT  FROM De█partments",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
