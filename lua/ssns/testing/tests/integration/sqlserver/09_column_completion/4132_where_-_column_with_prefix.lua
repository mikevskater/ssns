-- Test 4132: WHERE - column with prefix

return {
  number = 4132,
  description = "WHERE - column with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE First█",
  expected = {
    items = {
      excludes = {
        "LastName",
      },
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
