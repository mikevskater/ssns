-- Test 4720: Variable assignment - incompatible

return {
  number = 4720,
  description = "Variable assignment - incompatible",
  database = "vim_dadbod_test",
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
