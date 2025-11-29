-- Test 4104: SELECT - columns multiline

return {
  number = 4104,
  description = "SELECT - columns multiline",
  database = "vim_dadbod_test",
  query = [[SELECT
  EmployeeID,
  █
FROM Employees]],
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
