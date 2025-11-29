-- Test 4159: WHERE - CASE expression

return {
  number = 4159,
  description = "WHERE - CASE expression",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE CASE WHEN  █> 50000 THEN 1 ELSE 0 END = 1",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
