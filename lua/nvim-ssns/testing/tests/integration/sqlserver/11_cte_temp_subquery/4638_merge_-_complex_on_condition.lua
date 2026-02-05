-- Test 4638: MERGE - complex ON condition

return {
  number = 4638,
  description = "MERGE - complex ON condition",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID AND target.█ = source.DepartmentID]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
