-- Test 4577: UPDATE - WHERE clause columns

return {
  number = 4577,
  description = "UPDATE - WHERE clause columns",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Salary = 50000 WHERE █",
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
