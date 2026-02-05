-- Test 4093: UPDATE - multiline UPDATE

return {
  number = 4093,
  description = "UPDATE - multiline UPDATE",
  database = "vim_dadbod_test",
  query = [[UPDATE
  █]],
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
