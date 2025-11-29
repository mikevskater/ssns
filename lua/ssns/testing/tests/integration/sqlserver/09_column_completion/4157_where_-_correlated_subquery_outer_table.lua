-- Test 4157: WHERE - correlated subquery outer table

return {
  number = 4157,
  description = "WHERE - correlated subquery outer table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = e.)█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
