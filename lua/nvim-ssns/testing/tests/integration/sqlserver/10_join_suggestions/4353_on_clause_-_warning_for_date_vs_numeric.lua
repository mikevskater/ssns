-- Test 4353: ON clause - warning for date vs numeric
-- SKIPPED: Type mismatch warnings not yet supported

return {
  number = 4353,
  description = "ON clause - warning for date vs numeric",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type mismatch warnings not yet supported",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.ProjectI█D",
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
