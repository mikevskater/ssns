-- Test 4184: ON clause - fuzzy name matching (ID vs _ID)

return {
  number = 4184,
  description = "ON clause - fuzzy name matching (ID vs _ID)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.█",
  expected = {
    items = {
      includes_any = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
