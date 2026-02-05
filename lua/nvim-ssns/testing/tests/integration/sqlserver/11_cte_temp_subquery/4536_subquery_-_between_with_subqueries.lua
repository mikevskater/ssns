-- Test 4536: Subquery - BETWEEN with subqueries

return {
  number = 4536,
  description = "Subquery - BETWEEN with subqueries",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Salary BETWEEN (SELECT MIN()█ FROM Employees) AND (SELECT MAX(Salary) FROM Employees)",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
