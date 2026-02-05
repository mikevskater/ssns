-- Test 4513: Subquery - column completion in FROM subquery SELECT

return {
  number = 4513,
  description = "Subquery - column completion in FROM subquery SELECT",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT █ FROM Employees) sub",
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
