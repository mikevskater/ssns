-- Test 4357: ON clause - warning for bit vs varchar
-- SKIPPED: Type mismatch warnings not yet supported

return {
  number = 4357,
  description = "ON clause - warning for bit vs varchar",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type mismatch warnings not yet supported",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.IsActive = d.DepartmentNa█me",
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
