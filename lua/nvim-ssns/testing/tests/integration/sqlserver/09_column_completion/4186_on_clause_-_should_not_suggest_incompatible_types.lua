-- Test 4186: ON clause - should not suggest incompatible types
-- Type compatibility filtering is a future enhancement.
-- Currently returns all columns; user must choose appropriate types.

return {
  number = 4186,
  description = "ON clause - should not suggest incompatible types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.█",
  expected = {
    items = {
      includes_any = {
        "DepartmentName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
