-- Test 4717: UPDATE - SET from other column incompatible
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4717,
  description = "UPDATE - SET from other column incompatible",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "UPDATE Employees SET EmployeeID = FirstName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
