-- Test 4374: ON clause - hierarchical manager relationship

return {
  number = 4374,
  description = "ON clause - hierarchical manager relationship",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Employees mgr ON d.ManagerID = mgr.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
