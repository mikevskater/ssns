-- Test 4116: SELECT - multiline with alias

return {
  number = 4116,
  description = "SELECT - multiline with alias",
  database = "vim_dadbod_test",
  query = [[SELECT
  e.EmployeeID,
  e.█
FROM Employees e]],
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
