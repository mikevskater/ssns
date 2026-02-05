-- Test 4485: Temp table - multiple temp tables different batches
-- Local temp tables are NOT visible after GO (batch terminator)
-- Both #Temp1 and #Temp2 are in earlier batches, so neither visible

return {
  number = 4485,
  description = "Temp table - multiple temp tables different batches",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #Temp1 (Col1 INT)
GO
CREATE TABLE #Temp2 (Col2 VARCHAR(100))
GO
SELECT * FROM █]],
  expected = {
    items = {
      excludes = {
        "#Temp1",
        "#Temp2",
      },
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
