-- Test 4735: Edge case - alias shadows table name

return {
  number = 4735,
  description = "Edge case - alias shadows table name",
  database = "vim_dadbod_test",
  query = "SELECT Departments.█ FROM Employees Departments",
  expected = {
    items = {
      excludes = {
        "DepartmentName",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
