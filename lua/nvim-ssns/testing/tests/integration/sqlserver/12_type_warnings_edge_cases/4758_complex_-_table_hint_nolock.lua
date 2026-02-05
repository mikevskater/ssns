-- Test 4758: Complex - table hint NOLOCK

return {
  number = 4758,
  description = "Complex - table hint NOLOCK",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees WITH (NOLOCK)",
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
