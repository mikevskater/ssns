-- Test 4114: SELECT - alias with AS keyword

return {
  number = 4114,
  description = "SELECT - alias with AS keyword",
  database = "vim_dadbod_test",
  query = "SELECT emp.█ FROM Employees AS emp",
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
