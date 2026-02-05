-- Test 4662: Type compatibility - float = decimal (compatible)

return {
  number = 4662,
  description = "Type compatibility - float = decimal (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budge█t",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
