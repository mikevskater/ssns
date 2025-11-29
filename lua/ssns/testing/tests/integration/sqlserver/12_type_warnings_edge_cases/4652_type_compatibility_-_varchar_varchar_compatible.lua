-- Test 4652: Type compatibility - varchar = varchar (compatible)

return {
  number = 4652,
  description = "Type compatibility - varchar = varchar (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE FirstName = LastNa█me",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
