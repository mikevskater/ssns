-- Test 4167: ON clause - LEFT JOIN

return {
  number = 4167,
  description = "ON clause - LEFT JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT JOIN Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
