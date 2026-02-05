-- Test 4534: Subquery - NOT EXISTS subquery

return {
  number = 4534,
  description = "Subquery - NOT EXISTS subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d WHERE NOT EXISTS (SELECT 1 FROM Employees e WHERE e.DepartmentID = d.█)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
