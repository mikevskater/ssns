-- Test 4734: Edge case - alias same as table name

return {
  number = 4734,
  description = "Edge case - alias same as table name",
  database = "vim_dadbod_test",
  query = "SELECT Employees.█ FROM Employees Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
