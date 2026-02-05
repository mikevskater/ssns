-- Test 4105: SELECT - columns from schema-qualified table

return {
  number = 4105,
  description = "SELECT - columns from schema-qualified table",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM dbo.Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
