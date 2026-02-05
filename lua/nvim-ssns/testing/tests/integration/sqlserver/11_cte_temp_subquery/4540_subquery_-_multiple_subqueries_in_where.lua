-- Test 4540: Subquery - multiple subqueries in WHERE

return {
  number = 4540,
  description = "Subquery - multiple subqueries in WHERE",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees
WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE Budget > 100000)
AND DepartmentID IN (SELECT █ FROM Employees WHERE IsActive = 1)]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
