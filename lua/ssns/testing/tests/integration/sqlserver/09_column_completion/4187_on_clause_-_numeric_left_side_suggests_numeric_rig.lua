-- Test 4187: ON clause - numeric left side suggests numeric right

return {
  number = 4187,
  description = "ON clause - numeric left side suggests numeric right",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.Salary = d█.",
  expected = {
    items = {
      includes_any = {
        "Budget",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
