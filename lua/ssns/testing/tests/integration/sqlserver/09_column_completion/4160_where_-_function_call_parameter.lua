-- Test 4160: WHERE - function call parameter

return {
  number = 4160,
  description = "WHERE - function call parameter",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE YEAR()█ = 2024",
  expected = {
    items = {
      includes = {
        "HireDate",
      },
    },
    type = "column",
  },
}
