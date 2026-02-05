-- Test 4038: Schema-qualified - empty schema should show nothing

return {
  number = 4038,
  description = "Schema-qualified - empty schema should show nothing",
  database = "vim_dadbod_test",
  query = "SELECT * FROM nonexistent_schema.█",
  expected = {
    items = {
      count = 0,
    },
    type = "table",
  },
}
