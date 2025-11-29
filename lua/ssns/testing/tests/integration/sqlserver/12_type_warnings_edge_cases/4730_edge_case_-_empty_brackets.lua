-- Test 4730: Edge case - empty brackets

return {
  number = 4730,
  description = "Edge case - empty brackets",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [].█",
  expected = {
    type = "error",
  },
}
