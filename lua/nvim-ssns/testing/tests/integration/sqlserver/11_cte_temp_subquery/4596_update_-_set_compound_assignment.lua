-- Test 4596: UPDATE - SET compound assignment

return {
  number = 4596,
  description = "UPDATE - SET compound assignment",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Salary += █ WHERE EmployeeID = 1",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
