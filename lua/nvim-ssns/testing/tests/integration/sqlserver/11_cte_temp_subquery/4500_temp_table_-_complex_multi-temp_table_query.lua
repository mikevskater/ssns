-- Test 4500: Temp table - complex multi-temp table query
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4500,
  description = "Temp table - complex multi-temp table query",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #Temp1 (ID INT, DeptID INT)
CREATE TABLE #Temp2 (DeptID INT, DeptName VARCHAR(100))
SELECT t1.ID, t1.DeptID, t2.█
FROM #Temp1 t1
JOIN #Temp2 t2 ON t1.DeptID = t2.DeptID]],
  expected = {
    items = {
      includes = {
        "DeptName",
      },
    },
    type = "column",
  },
}
