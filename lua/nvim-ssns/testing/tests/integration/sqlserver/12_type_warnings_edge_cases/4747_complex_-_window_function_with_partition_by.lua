-- Test 4747: Complex - window function with PARTITION BY

return {
  number = 4747,
  description = "Complex - window function with PARTITION BY",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, ROW_NUMBER() OVER (PARTITION BY █ ORDER BY Salary DESC) FROM Employees",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
