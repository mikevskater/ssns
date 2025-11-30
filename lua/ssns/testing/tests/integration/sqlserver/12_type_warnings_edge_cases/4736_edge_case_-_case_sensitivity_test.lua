-- Test 4736: Edge case - case sensitivity test

return {
  number = 4736,
  description = "Edge case - case sensitivity test",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT EMPLOYEEID, employeeid, █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
