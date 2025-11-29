-- Test 4174: ON clause - second JOIN linking to second table

return {
  number = 4174,
  description = "ON clause - second JOIN linking to second table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
