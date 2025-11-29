-- Test 4715: UPDATE - SET incompatible types

return {
  number = 4715,
  description = "UPDATE - SET incompatible types",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET EmployeeID = 'text'█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "conversion_error",
      },
    },
    type = "warning",
  },
}
