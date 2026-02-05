-- Test 4233: Subquery - correlated subquery outer reference

return {
  number = 4233,
  description = "Subquery - correlated subquery outer reference",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = e.█)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
