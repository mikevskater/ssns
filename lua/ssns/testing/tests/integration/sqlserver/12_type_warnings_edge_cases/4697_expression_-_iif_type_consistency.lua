-- Test 4697: Expression - IIF type consistency

return {
  number = 4697,
  description = "Expression - IIF type consistency",
  database = "vim_dadbod_test",
  query = "SELECT IIF(IsActive = 1, Salary, 'None') █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
