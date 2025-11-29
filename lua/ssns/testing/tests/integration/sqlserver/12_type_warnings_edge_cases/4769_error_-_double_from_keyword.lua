-- Test 4769: Error - double FROM keyword

return {
  number = 4769,
  description = "Error - double FROM keyword",
  database = "vim_dadbod_test",
  query = "SELECT * FROM FROM █Employees",
  expected = {
    type = "error",
  },
}
