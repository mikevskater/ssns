-- Test 4231: Subquery - columns in SELECT subquery

return {
  number = 4231,
  description = "Subquery - columns in SELECT subquery",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, (SELECT█  FROM Departments WHERE DepartmentID = e.DepartmentID) FROM Employees e",
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
