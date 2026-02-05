-- Test 4129: SELECT - invalid alias shows no columns

return {
  number = 4129,
  description = "SELECT - invalid alias shows no columns",
  database = "vim_dadbod_test",
  query = "SELECT x.█ FROM Employees e",
  expected = {
    items = {
      count = 0,
    },
    type = "column",
  },
}
