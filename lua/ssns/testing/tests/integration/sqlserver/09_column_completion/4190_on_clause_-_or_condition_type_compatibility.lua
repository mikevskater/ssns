-- Test 4190: ON clause - OR condition type compatibility

return {
  number = 4190,
  description = "ON clause - OR condition type compatibility",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID OR e.EmployeeID = d.█",
  expected = {
    items = {
      includes_any = {
        "ManagerID",
      },
    },
    type = "column",
  },
}
