-- Test 4176: ON clause - all tables available

return {
  number = 4176,
  description = "ON clause - all tables available",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON █",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "DepartmentID",
        "ProjectID",
      },
    },
    type = "column",
  },
}
