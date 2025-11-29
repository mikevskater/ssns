-- Test 4696: Expression - COALESCE type consistency

return {
  number = 4696,
  description = "Expression - COALESCE type consistency",
  database = "vim_dadbod_test",
  query = "SELECT COALESCE(DepartmentID, FirstName) F█ROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
