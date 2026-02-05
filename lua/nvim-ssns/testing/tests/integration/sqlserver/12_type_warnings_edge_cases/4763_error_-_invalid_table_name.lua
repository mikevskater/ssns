-- Test 4763: Error - invalid table name

return {
  number = 4763,
  description = "Error - invalid table name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM NonExistentTable WHERE █",
  expected = {
    items = {
      count = 0,
    },
    type = "column",
  },
}
