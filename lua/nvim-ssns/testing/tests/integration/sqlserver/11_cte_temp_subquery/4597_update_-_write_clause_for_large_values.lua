-- Test 4597: UPDATE - WRITE clause for large values

return {
  number = 4597,
  description = "UPDATE - WRITE clause for large values",
  database = "vim_dadbod_test",
  query = "UPDATE Documents SET Content.WRITE(█) WHERE DocID = 1",
  expected = {
    items = {
    },
    type = "none",
  },
}
