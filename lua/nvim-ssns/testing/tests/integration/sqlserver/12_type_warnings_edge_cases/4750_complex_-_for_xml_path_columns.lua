-- Test 4750: Complex - FOR XML PATH columns

return {
  number = 4750,
  description = "Complex - FOR XML PATH columns",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees FOR XML PATH('Employee'), ROOT('Employees')",
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
