-- Test 4155: WHERE - IS NULL check on nullable column

return {
  number = 4155,
  description = "WHERE - IS NULL check on nullable column",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE  █IS NULL",
  expected = {
    items = {
      includes = {
        "Email",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
