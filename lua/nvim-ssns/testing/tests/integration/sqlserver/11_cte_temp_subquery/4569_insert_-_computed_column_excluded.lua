-- Test 4569: INSERT - computed column excluded

return {
  number = 4569,
  description = "INSERT - computed column excluded",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees █() VALUES (1, 'John')",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
