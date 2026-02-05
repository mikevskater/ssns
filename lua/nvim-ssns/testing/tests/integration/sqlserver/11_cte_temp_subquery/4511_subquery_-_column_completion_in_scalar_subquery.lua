-- Test 4511: Subquery - column completion in scalar subquery

return {
  number = 4511,
  description = "Subquery - column completion in scalar subquery",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, (SELECT █ FROM Departments WHERE DepartmentID = e.DepartmentID) FROM Employees e",
  expected = {
    items = {
      includes = {
        "DepartmentName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
