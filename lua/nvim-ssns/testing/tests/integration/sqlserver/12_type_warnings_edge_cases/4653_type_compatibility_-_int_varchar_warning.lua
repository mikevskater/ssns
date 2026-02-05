-- Test 4653: Type compatibility - int = varchar (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4653,
  description = "Type compatibility - int = varchar (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT * FROM Employees WHERE EmployeeID = FirstN█ame",
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
