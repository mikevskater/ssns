-- Test 4149: WHERE - LIKE operator

return {
  number = 4149,
  description = "WHERE - LIKE operator",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE █ LIKE '%John%'",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
