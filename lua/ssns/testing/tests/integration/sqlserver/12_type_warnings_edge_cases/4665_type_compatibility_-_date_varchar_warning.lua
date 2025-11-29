-- Test 4665: Type compatibility - date = varchar (warning)

return {
  number = 4665,
  description = "Type compatibility - date = varchar (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Projects WHERE StartDate = ProjectName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
