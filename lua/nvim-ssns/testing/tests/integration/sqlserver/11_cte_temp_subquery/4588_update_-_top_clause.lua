-- Test 4588: UPDATE - TOP clause

return {
  number = 4588,
  description = "UPDATE - TOP clause",
  database = "vim_dadbod_test",
  skip = false,
  query = "UPDATE TOP (10) Employees SET █ = 50000",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
