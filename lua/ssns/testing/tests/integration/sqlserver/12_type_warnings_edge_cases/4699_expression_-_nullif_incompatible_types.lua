-- Test 4699: Expression - NULLIF incompatible types

return {
  number = 4699,
  description = "Expression - NULLIF incompatible types",
  database = "vim_dadbod_test",
  query = "SELECT NULLIF(EmployeeID, FirstName) █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
