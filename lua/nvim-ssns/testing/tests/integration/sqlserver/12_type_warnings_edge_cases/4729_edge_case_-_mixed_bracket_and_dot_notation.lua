-- Test 4729: Edge case - mixed bracket and dot notation

return {
  number = 4729,
  description = "Edge case - mixed bracket and dot notation",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [dbo].[Employees]█ ",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
