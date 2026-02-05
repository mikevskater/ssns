-- Test 4574: UPDATE - SET column with prefix

return {
  number = 4574,
  description = "UPDATE - SET column with prefix",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Sal█",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
