-- Test 4169: ON clause - FULL OUTER JOIN

return {
  number = 4169,
  description = "ON clause - FULL OUTER JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e FULL OUTER JOIN Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
