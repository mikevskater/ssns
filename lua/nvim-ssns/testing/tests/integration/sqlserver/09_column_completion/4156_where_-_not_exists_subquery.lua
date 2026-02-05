-- Test 4156: WHERE - NOT EXISTS subquery

return {
  number = 4156,
  description = "WHERE - NOT EXISTS subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM Departments d WHERE d.DepartmentID = e.)█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
