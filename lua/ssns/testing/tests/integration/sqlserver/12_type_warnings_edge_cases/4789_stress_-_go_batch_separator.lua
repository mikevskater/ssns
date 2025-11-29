-- Test 4789: Stress - GO batch separator

return {
  number = 4789,
  description = "Stress - GO batch separator",
  database = "vim_dadbod_test",
  query = [[SELECT 1
GO
SELECT █ FROM Employees]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
