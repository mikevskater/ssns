-- Test 4695: Expression - CASE result type consistency

return {
  number = 4695,
  description = "Expression - CASE result type consistency",
  database = "vim_dadbod_test",
  query = "SELECT CASE WHEN IsActive = 1 THEN Salary ELSE 'N/A' END █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "case_type_inconsistency",
      },
    },
    type = "warning",
  },
}
