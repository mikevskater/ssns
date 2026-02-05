-- Test 4360: ON clause - compatible nullable columns

return {
  number = 4360,
  description = "ON clause - compatible nullable columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.Departmen█tID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
