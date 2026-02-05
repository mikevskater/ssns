-- Test 4201: GROUP BY - basic column completion

return {
  number = 4201,
  description = "GROUP BY - basic column completion",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY █",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "FirstName",
      },
    },
    type = "column",
  },
}
