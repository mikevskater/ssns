-- Test 4761: Error - incomplete SELECT

return {
  number = 4761,
  description = "Error - incomplete SELECT",
  database = "vim_dadbod_test",
  query = "SELECT █",
  expected = {
    items = {
      count = 0,
    },
    type = "column",
  },
}
