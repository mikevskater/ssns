-- Test 4508: Subquery - nested subquery table completion

return {
  number = 4508,
  description = "Subquery - nested subquery table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE ManagerID IN (SELECT EmployeeID FROM █ ))",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
