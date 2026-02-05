-- Test 4476: Temp table - with multiple data types
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4476,
  description = "Temp table - with multiple data types",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempData (
  IntCol INT,
  BigIntCol BIGINT,
  DecimalCol DECIMAL(18,2),
  VarcharCol VARCHAR(MAX),
  NVarcharCol NVARCHAR(100),
  DateCol DATE,
  DateTimeCol DATETIME2,
  BitCol BIT,
  UniqueCol UNIQUEIDENTIFIER
)
SELECT █ FROM #TempData]],
  expected = {
    items = {
      includes = {
        "IntCol",
        "BigIntCol",
        "DecimalCol",
        "VarcharCol",
        "DateCol",
        "BitCol",
      },
    },
    type = "column",
  },
}
