-- Test 4535: Subquery - comparison with subquery

return {
  number = 4535,
  description = "Subquery - comparison with subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Salary = (SELECT MAX()█ FROM Employees)",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
