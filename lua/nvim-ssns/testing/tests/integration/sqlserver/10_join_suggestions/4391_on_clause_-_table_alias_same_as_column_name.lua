-- Test 4391: ON clause - table alias same as column name

return {
  number = 4391,
  description = "ON clause - table alias same as column name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees EmployeeID JOIN Departments d ON EmployeeID.█",
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
