-- Test 4642: MERGE - table variable as source
-- SKIPPED: Table variable completion not yet supported

return {
  number = 4642,
  description = "MERGE - table variable as source",
  database = "vim_dadbod_test",
  skip = false,
  query = [[DECLARE @Staging TABLE (ID INT, Name VARCHAR(100))
MERGE INTO Employees AS target
USING @Staging AS source
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
