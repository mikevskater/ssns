-- Test 4301: FK suggestion - Employees -> Departments (1 hop)

return {
  number = 4301,
  description = "FK suggestion - Employees -> Departments (1 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
