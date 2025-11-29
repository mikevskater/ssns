-- Test 4222: UPDATE SET - second column

return {
  number = 4222,
  description = "UPDATE SET - second column",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET FirstName = 'John', █",
  expected = {
    items = {
      includes = {
        "LastName",
        "Salary",
      },
    },
    type = "column",
  },
}
