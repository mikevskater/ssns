-- Test 4756: Complex - temporal table FOR SYSTEM_TIME

return {
  number = 4756,
  description = "Complex - temporal table FOR SYSTEM_TIME",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees FOR SYSTEM_TIME AS OF '2024-01-01'",
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
