-- Test 4176: ON clause - all tables available

return {
  number = 4176,
  description = "ON clause - all tables available",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON █",
  expected = {
    items = {
      -- ON clause with multiple tables returns qualified columns
      includes_any = {
        "e.EmployeeID",
        "d.DepartmentID",
        "p.ProjectID",
      },
    },
    type = "column",
  },
}
