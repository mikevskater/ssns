-- Test 4669: Type compatibility - decimal = decimal (compatible)

return {
  number = 4669,
  description = "Type compatibility - decimal = decimal (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.Salary = d.Budget█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
