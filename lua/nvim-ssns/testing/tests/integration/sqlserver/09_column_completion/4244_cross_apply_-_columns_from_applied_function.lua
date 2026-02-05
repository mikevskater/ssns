-- Test 4244: CROSS APPLY - columns from applied function

return {
  number = 4244,
  description = "CROSS APPLY - columns from applied function",
  database = "vim_dadbod_test",
  query = "SELECT e.*, f.█ FROM Employees e CROSS APPLY fn_GetEmployeesBySalaryRange(50000, 100000) AS f",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
