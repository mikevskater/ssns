-- Test 4666: Type compatibility - decimal = varchar (warning)

return {
  number = 4666,
  description = "Type compatibility - decimal = varchar (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Projects WHERE Budget = ProjectName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
