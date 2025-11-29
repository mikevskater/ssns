-- Test 4134: WHERE - after AND

return {
  number = 4134,
  description = "WHERE - after AND",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = 1 AND █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
