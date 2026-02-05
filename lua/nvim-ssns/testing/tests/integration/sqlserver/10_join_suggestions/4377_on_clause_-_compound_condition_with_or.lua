-- Test 4377: ON clause - compound condition with OR

return {
  number = 4377,
  description = "ON clause - compound condition with OR",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID OR e.EmployeeID = d.█]],
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
