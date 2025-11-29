-- Test 4239: EXISTS subquery - columns

return {
  number = 4239,
  description = "EXISTS subquery - columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Departments d WHERE d.ManagerID = e.)█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
