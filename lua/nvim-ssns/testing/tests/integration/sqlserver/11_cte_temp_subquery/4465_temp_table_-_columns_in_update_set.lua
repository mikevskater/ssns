-- Test 4465: Temp table - columns in UPDATE SET
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4465,
  description = "Temp table - columns in UPDATE SET",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
UPDATE #TempEmployees SET █ = 'New Value']],
  expected = {
    items = {
      includes = {
        "Name",
        "Salary",
      },
    },
    type = "column",
  },
}
