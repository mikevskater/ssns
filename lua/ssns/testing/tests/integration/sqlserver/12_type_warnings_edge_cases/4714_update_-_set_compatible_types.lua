-- Test 4714: UPDATE - SET compatible types

return {
  number = 4714,
  description = "UPDATE - SET compatible types",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Salary = 50000█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
