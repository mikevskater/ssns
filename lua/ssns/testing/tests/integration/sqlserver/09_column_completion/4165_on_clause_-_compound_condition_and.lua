-- Test 4165: ON clause - compound condition AND

return {
  number = 4165,
  description = "ON clause - compound condition AND",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e█.",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
