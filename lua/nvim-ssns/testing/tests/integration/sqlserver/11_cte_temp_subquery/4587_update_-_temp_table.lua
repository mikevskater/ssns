-- Test 4587: UPDATE - temp table
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4587,
  description = "UPDATE - temp table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100), Salary DECIMAL)
UPDATE #TempEmp SET █]],
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
