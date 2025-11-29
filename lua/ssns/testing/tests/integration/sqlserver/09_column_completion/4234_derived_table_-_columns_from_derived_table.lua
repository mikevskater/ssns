-- Test 4234: Derived table - columns from derived table

return {
  number = 4234,
  description = "Derived table - columns from derived table",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM (SELECT EmployeeID, FirstName FROM Employees) AS sub",
  expected = {
    items = {
      excludes = {
        "LastName",
        "Salary",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
