-- Test 4507: Subquery - table completion in SELECT CASE subquery

return {
  number = 4507,
  description = "Subquery - table completion in SELECT CASE subquery",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, CASE WHEN Salary > (SELECT AVG(Salary) FROM █) THEN 'High' ELSE 'Low' END FROM Employees",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
