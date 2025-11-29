-- Test 4658: Type compatibility - bit = varchar (warning)

return {
  number = 4658,
  description = "Type compatibility - bit = varchar (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE IsActive = FirstNa█me",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
