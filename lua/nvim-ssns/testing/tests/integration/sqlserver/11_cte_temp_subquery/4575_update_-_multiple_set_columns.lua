-- Test 4575: UPDATE - multiple SET columns

return {
  number = 4575,
  description = "UPDATE - multiple SET columns",
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
