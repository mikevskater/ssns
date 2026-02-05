-- Test 4303: FK suggestion - Orders -> Employees (1 hop)

return {
  number = 4303,
  description = "FK suggestion - Orders -> Employees (1 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
