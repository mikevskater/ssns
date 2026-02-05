-- Test 4641: MERGE - temp table as source
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4641,
  description = "MERGE - temp table as source",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #Staging (ID INT, Name VARCHAR(100))
MERGE INTO Employees AS target
USING #Staging AS source
ON target.EmployeeID = source.█]],
  expected = {
    items = {
      includes = {
        "ID",
      },
    },
    type = "column",
  },
}
