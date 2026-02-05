-- Test 4494: Temp table - name with underscores
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4494,
  description = "Temp table - name with underscores",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #Temp_Table_Name (ID INT)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#Temp_Table_Name",
      },
    },
    type = "table",
  },
}
