-- Test 4706: Expression - DATEADD with non-date column

return {
  number = 4706,
  description = "Expression - DATEADD with non-date column",
  database = "vim_dadbod_test",
  query = "SELECT DATEADD(day, 30, FirstName) █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "invalid_argument",
      },
    },
    type = "warning",
  },
}
