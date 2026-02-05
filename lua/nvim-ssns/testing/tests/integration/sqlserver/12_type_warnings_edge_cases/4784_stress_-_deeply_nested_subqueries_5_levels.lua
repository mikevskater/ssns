-- Test 4784: Stress - deeply nested subqueries (5 levels)

return {
  number = 4784,
  description = "Stress - deeply nested subqueries (5 levels)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT█  FROM Employees) l1) l2) l3) l4",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
