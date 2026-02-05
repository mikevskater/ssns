-- Test 4171: ON clause - second JOIN left side

return {
  number = 4171,
  description = "ON clause - second JOIN left side",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON █",
  expected = {
    items = {
      -- ON clause with multiple tables returns qualified columns
      includes_any = {
        "p.ProjectID",
        "d.DepartmentID",
        "e.DepartmentID",
      },
    },
    type = "column",
  },
}
