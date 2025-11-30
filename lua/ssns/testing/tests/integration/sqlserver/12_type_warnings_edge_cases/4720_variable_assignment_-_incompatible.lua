-- Test 4720: Variable assignment - incompatible
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4720,
  description = "Variable assignment - incompatible",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "DECLARE @id INT; SELECT @id = FirstName FRO█M Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "implicit_conversion",
      },
    },
    type = "warning",
  },
}
