-- Test 4604: DELETE - WHERE clause columns

return {
  number = 4604,
  description = "DELETE - WHERE clause columns",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "IsActive",
      },
    },
    type = "column",
  },
}
