-- Test 4655: Type compatibility - datetime = date (compatible)

return {
  number = 4655,
  description = "Type compatibility - datetime = date (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDa█te",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
