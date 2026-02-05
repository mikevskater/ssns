-- Test 4555: INSERT - column list with prefix filter

return {
  number = 4555,
  description = "INSERT - column list with prefix filter",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (First█) VALUES ('John')",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
