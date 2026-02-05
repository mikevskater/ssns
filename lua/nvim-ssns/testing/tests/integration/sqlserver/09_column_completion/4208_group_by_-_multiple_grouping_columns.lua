-- Test 4208: GROUP BY - multiple grouping columns

return {
  number = 4208,
  description = "GROUP BY - multiple grouping columns",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, Email, █",
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
