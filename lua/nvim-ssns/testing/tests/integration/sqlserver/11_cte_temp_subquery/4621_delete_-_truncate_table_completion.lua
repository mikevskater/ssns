-- Test 4621: DELETE - TRUNCATE TABLE completion
-- SKIPPED: TRUNCATE TABLE completion not yet supported

return {
  number = 4621,
  description = "DELETE - TRUNCATE TABLE completion",
  database = "vim_dadbod_test",
  skip = false,
  query = "TRUNCATE TABLE █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Projects",
      },
    },
    type = "table",
  },
}
