-- Test 4685: JOIN ON - decimal precision compatible

return {
  number = 4685,
  description = "JOIN ON - decimal precision compatible",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budge█t",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
