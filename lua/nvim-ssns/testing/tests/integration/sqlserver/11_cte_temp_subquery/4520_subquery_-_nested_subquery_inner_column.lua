-- Test 4520: Subquery - nested subquery inner column

return {
  number = 4520,
  description = "Subquery - nested subquery inner column",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE █ > 100)",
  expected = {
    items = {
      includes = {
        "Budget",
        "ManagerID",
      },
    },
    type = "column",
  },
}
