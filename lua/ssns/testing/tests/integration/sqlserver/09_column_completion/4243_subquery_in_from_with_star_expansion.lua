-- Test 4243: Subquery in FROM with star expansion

return {
  number = 4243,
  description = "Subquery in FROM with star expansion",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM (SELECT * FROM Employees WHERE DepartmentID = 1) AS filtered",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
