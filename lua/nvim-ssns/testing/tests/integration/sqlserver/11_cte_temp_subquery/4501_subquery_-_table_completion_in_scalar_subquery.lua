-- Test 4501: Subquery - table completion in scalar subquery

return {
  number = 4501,
  description = "Subquery - table completion in scalar subquery",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, (SELECT DepartmentName FROM █) FROM Employees",
  expected = {
    items = {
      includes = {
        "Departments",
        "Employees",
      },
    },
    type = "table",
  },
}
