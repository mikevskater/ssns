-- Test 4202: GROUP BY - second column

return {
  number = 4202,
  description = "GROUP BY - second column",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, █",
  expected = {
    items = {
      includes = {
        "Email",
        "FirstName",
      },
    },
    type = "column",
  },
}
