-- Test 4458: Temp table - INSERT INTO temp table
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4458,
  description = "Temp table - INSERT INTO temp table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
INSERT INTO █ (ID, Name) VALUES (1, 'Test')]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
