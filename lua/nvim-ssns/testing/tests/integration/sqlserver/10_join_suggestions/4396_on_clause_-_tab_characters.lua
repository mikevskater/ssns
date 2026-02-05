-- Test 4396: ON clause - tab characters
-- SKIPPED: Tab character handling in ON clause not yet supported

return {
  number = 4396,
  description = "ON clause - tab characters",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT * FROM Employees e JOIN Departments d ON\9e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
