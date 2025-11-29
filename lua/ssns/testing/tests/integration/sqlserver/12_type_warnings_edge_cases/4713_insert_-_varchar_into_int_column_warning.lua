-- Test 4713: INSERT - varchar into int column (warning)

return {
  number = 4713,
  description = "INSERT - varchar into int column (warning)",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (EmployeeID) VALUES ('abc█')",
  expected = {
    items = {
      includes_any = {
        "conversion_error",
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
