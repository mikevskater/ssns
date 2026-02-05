-- Test 4139: WHERE - with IN clause

return {
  number = 4139,
  description = "WHERE - with IN clause",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT █ FROM Departments)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
