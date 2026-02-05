-- Test 4120: SELECT - multiple columns with alias prefix

return {
  number = 4120,
  description = "SELECT - multiple columns with alias prefix",
  database = "vim_dadbod_test",
  query = "SELECT e.EmployeeID, e.FirstName, e.█ FROM Employees e",
  expected = {
    items = {
      includes = {
        "LastName",
        "DepartmentID",
        "Salary",
      },
    },
    type = "column",
  },
}
