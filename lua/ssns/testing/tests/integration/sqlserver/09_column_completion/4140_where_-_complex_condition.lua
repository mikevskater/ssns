-- Test 4140: WHERE - complex condition

return {
  number = 4140,
  description = "WHERE - complex condition",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE (EmployeeID > 5 AND █) OR DepartmentID = 1",
  expected = {
    items = {
      includes = {
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
