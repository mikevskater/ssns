-- Test 4189: ON clause - complex condition with mixed types

return {
  number = 4189,
  description = "ON clause - complex condition with mixed types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.EmployeeID = d.█",
  expected = {
    items = {
      includes_any = {
        "ManagerID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
