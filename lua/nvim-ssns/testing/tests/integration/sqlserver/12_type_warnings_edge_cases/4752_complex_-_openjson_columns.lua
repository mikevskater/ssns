-- Test 4752: Complex - OPENJSON columns
-- SKIPPED: OPENJSON WITH clause column completion not yet supported

return {
  number = 4752,
  description = "Complex - OPENJSON columns",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "OPENJSON WITH clause column completion not yet supported",
  query = "SELECT █ FROM OPENJSON(@json) WITH (ID INT, Name VARCHAR(100))",
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
