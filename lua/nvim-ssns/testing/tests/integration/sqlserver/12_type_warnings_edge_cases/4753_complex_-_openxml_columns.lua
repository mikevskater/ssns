-- Test 4753: Complex - OPENXML columns
-- SKIPPED: OPENXML WITH clause column completion not yet supported

return {
  number = 4753,
  description = "Complex - OPENXML columns",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "OPENXML WITH clause column completion not yet supported",
  query = "SELECT █ FROM OPENXML(@hdoc, '/root/emp') WITH (ID INT, Name VARCHAR(100))",
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
