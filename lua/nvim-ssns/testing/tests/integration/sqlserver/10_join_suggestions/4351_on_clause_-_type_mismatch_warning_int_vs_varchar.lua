-- Test 4351: ON clause - type mismatch warning (int vs varchar)
-- SKIPPED: Type mismatch warnings not yet supported

return {
  number = 4351,
  description = "ON clause - type mismatch warning (int vs varchar)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type mismatch warnings not yet supported",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentID█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "incompatible_types",
      },
    },
    type = "warning",
  },
}
