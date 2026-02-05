-- Test 4531: Subquery - ALL operator subquery

return {
  number = 4531,
  description = "Subquery - ALL operator subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Salary > ALL (SELECT █ FROM Employees WHERE DepartmentID = 1)",
  expected = {
    items = {
      includes_any = {
        "Salary",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
