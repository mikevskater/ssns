-- Test 4663: Type compatibility - int = int (compatible)

return {
  number = 4663,
  description = "Type compatibility - int = int (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID = Employe█eID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
