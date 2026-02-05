-- Test 4503: Subquery - table completion in EXISTS subquery

return {
  number = 4503,
  description = "Subquery - table completion in EXISTS subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM █)",
  expected = {
    items = {
      includes = {
        "Departments",
        "Orders",
      },
    },
    type = "table",
  },
}
