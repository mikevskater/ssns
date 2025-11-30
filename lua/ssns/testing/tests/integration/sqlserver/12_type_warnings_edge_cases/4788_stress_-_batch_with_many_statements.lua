-- Test 4788: Stress - batch with many statements

return {
  number = 4788,
  description = "Stress - batch with many statements",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT 1; SELECT 2; SELECT 3; SELECT 4; SELECT 5; SELECT █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
