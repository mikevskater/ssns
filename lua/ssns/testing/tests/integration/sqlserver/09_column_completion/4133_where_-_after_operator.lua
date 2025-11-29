-- Test 4133: WHERE - after = operator

return {
  number = 4133,
  description = "WHERE - after = operator",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
