-- Test 4744: Complex - INTERSECT query

return {
  number = 4744,
  description = "Complex - INTERSECT query",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "INTERSECT/UNION second SELECT clause context detection not yet supported",
  query = "SELECT DepartmentID FROM Employees INTERSECT SELECT █ FROM Departments",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
