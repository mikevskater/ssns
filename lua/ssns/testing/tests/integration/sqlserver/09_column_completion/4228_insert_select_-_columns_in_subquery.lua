-- Test 4228: INSERT SELECT - columns in subquery

return {
  number = 4228,
  description = "INSERT SELECT - columns in subquery",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (FirstName, LastName) SELECT █ FROM Employees",
  expected = {
    items = {
      includes_any = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
