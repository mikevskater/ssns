-- Test 4797: Context - cursor inside comment

return {
  number = 4797,
  description = "Context - cursor inside comment",
  database = "vim_dadbod_test",
  query = "SELECT * /* comment █ */ FROM Employees",
  expected = {
    type = "none",
  },
}
