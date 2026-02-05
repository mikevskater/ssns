-- Test 4751: Complex - FOR JSON PATH columns

return {
  number = 4751,
  description = "Complex - FOR JSON PATH columns",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees FOR JSON PATH",
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
