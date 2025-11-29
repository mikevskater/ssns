-- Test 4106: SELECT - columns from bracketed table

return {
  number = 4106,
  description = "SELECT - columns from bracketed table",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM [Employees",
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
