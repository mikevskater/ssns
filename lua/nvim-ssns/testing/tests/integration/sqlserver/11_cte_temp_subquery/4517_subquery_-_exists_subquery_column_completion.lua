-- Test 4517: Subquery - EXISTS subquery column completion

return {
  number = 4517,
  description = "Subquery - EXISTS subquery column completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Departments d WHERE d.DepartmentID = e.█)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
