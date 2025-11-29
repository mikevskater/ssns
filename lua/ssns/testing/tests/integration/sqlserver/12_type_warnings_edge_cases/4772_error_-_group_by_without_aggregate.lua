-- Test 4772: Error - GROUP BY without aggregate

return {
  number = 4772,
  description = "Error - GROUP BY without aggregate",
  database = "vim_dadbod_test",
  query = "SELECT FirstName, █ FROM Employees GROUP BY DepartmentID",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
