-- Test 4667: Type compatibility - int = decimal (compatible)

return {
  number = 4667,
  description = "Type compatibility - int = decimal (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments WHERE DepartmentID = Budget█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
