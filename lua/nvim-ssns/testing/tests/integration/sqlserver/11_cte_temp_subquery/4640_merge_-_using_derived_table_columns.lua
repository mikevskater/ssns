-- Test 4640: MERGE - USING derived table columns
-- SKIPPED: MERGE derived table column completion not yet supported

return {
  number = 4640,
  description = "MERGE - USING derived table columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.█]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
      },
      includes = {
        "ID",
      },
    },
    type = "column",
  },
}
