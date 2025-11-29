-- Test 4748: Complex - window function with ROWS BETWEEN

return {
  number = 4748,
  description = "Complex - window function with ROWS BETWEEN",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, SUM(Salary) OVER (ORDER BY █ ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) FROM Employees",
  expected = {
    items = {
      includes = {
        "HireDate",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
