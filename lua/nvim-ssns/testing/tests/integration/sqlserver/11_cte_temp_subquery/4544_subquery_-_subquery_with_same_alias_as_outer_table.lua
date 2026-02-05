-- Test 4544: Subquery - subquery with same alias as outer table

return {
  number = 4544,
  description = "Subquery - subquery with same alias as outer table",
  database = "vim_dadbod_test",
  query = "SELECT e.█ FROM Employees e WHERE DepartmentID IN (SELECT DepartmentID FROM Departments e)",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
