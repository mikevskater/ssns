-- Test 4797: Context - cursor inside comment
-- SKIPPED: None type completion not yet supported

return {
  number = 4797,
  description = "Context - cursor inside comment",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "None type completion not yet supported",
  query = "SELECT * /* comment █ */ FROM Employees",
  expected = {
    items = { includes = {} },
    type = "none",
  },
}
