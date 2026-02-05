-- Test 4565: INSERT - TOP with SELECT

return {
  number = 4565,
  description = "INSERT - TOP with SELECT",
  database = "vim_dadbod_test",
  query = "INSERT TOP (100) INTO Archive SELECT █ FROM Employees",
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
