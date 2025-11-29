-- Test 4168: ON clause - RIGHT JOIN

return {
  number = 4168,
  description = "ON clause - RIGHT JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d RIGHT JOIN Employees e ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
