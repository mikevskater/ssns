-- Test 4166: ON clause - multiline

return {
  number = 4166,
  description = "ON clause - multiline",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
  AND e.█ = d.ManagerID]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
