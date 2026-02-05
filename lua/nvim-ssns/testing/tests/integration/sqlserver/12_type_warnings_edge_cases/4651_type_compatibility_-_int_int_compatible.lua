-- Test 4651: Type compatibility - int = int (compatible)

return {
  number = 4651,
  description = "Type compatibility - int = int (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = Departmen█tID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
