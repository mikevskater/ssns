-- Test 4238: Nested subquery - inner subquery columns

return {
  number = 4238,
  description = "Nested subquery - inner subquery columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE ManagerID IN (SELECT █ FROM Employees))",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
