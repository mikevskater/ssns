-- Test 4670: Type compatibility - date = date (compatible)

return {
  number = 4670,
  description = "Type compatibility - date = date (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDa█te",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
