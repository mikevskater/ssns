-- Test 4265: CTE - three CTEs chain

return {
  number = 4265,
  description = "CTE - three CTEs chain",
  database = "vim_dadbod_test",
  query = [[WITH
  A AS (SELECT EmployeeID, DepartmentID FROM Employees),
  B AS (SELECT DepartmentID, DepartmentName FROM Departments),
  C AS (SELECT a.EmployeeID, b.DepartmentName FROM A a JOIN B b ON a.DepartmentID = b.DepartmentID)
SELECT █ FROM C]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
