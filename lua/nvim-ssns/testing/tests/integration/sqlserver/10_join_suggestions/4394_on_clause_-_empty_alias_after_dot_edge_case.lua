-- Test 4394: ON clause - empty alias after dot (edge case)

return {
  number = 4394,
  description = "ON clause - empty alias after dot (edge case)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "FirstName",
      },
    },
    type = "column",
  },
}
