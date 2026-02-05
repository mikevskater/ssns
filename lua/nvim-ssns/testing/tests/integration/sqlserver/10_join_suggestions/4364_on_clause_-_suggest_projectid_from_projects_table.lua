-- Test 4364: ON clause - suggest ProjectID from Projects table

return {
  number = 4364,
  description = "ON clause - suggest ProjectID from Projects table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.EmployeeID = p.█",
  expected = {
    items = {
      includes = {
        "ProjectID",
      },
    },
    type = "column",
  },
}
