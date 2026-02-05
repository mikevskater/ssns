-- Test 4235: Derived table - alias-qualified

return {
  number = 4235,
  description = "Derived table - alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees) AS sub",
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
