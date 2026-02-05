-- Test 4568: INSERT - identity column excluded suggestion

return {
  number = 4568,
  description = "INSERT - identity column excluded suggestion",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees █() VALUES ('John')",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
