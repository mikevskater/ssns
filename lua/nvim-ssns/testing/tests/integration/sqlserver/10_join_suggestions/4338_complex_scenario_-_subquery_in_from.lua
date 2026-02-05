-- Test 4338: Complex scenario - subquery in FROM

return {
  number = 4338,
  description = "Complex scenario - subquery in FROM",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT * FROM Employees WHERE DepartmentID = 1) e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
