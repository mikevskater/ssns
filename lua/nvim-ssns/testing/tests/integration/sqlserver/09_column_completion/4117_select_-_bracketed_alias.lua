-- Test 4117: SELECT - bracketed alias

return {
  number = 4117,
  description = "SELECT - bracketed alias",
  database = "vim_dadbod_test",
  query = "SELECT [e].█ FROM Employees [e]",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
