-- Test 4589: UPDATE - table variable
-- SKIPPED: Table variable completion not yet supported

return {
  number = 4589,
  description = "UPDATE - table variable",
  database = "vim_dadbod_test",
  skip = false,
  query = [[DECLARE @Emp TABLE (ID INT, Name VARCHAR(100))
UPDATE @Emp SET █]],
  expected = {
    items = {
      includes = {
        "Name",
      },
    },
    type = "column",
  },
}
