-- Test 4179: ON clause - self-join second alias

return {
  number = 4179,
  description = "ON clause - self-join second alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Employees m ON m.█",
  expected = {
    items = {
      -- Self-join - m. alias returns Employees columns (ManagerID doesn't exist in this schema)
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
