-- Test 4736: Edge case - case sensitivity test

return {
  number = 4736,
  description = "Edge case - case sensitivity test",
  database = "vim_dadbod_test",
  query = "SELECT EMPLOYEEID, employeeid, EmployeeID FRO█M Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
