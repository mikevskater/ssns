-- Test 4637: MERGE - WITH CTE source

return {
  number = 4637,
  description = "MERGE - WITH CTE source",
  database = "vim_dadbod_test",
  query = [[WITH StagingCTE AS (SELECT * FROM Employees WHERE IsActive = 1)
MERGE INTO Employees AS target
USING █ AS source
ON target.EmployeeID = source.EmployeeID]],
  expected = {
    items = {
      includes = {
        "StagingCTE",
      },
    },
    type = "table",
  },
}
