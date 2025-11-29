-- Test 4236: Derived table - with expression alias

return {
  number = 4236,
  description = "Derived table - with expression alias",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees) sub",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FullName",
      },
    },
    type = "column",
  },
}
