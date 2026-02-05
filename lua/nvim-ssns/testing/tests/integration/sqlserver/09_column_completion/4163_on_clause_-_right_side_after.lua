-- Test 4163: ON clause - right side after =

return {
  number = 4163,
  description = "ON clause - right side after =",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = █",
  expected = {
    items = {
      -- ON clause returns qualified columns when multiple tables in scope
      includes_any = {
        "d.DepartmentID",
        "e.DepartmentID",
      },
    },
    type = "column",
  },
}
