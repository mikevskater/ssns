-- Test 4253: CTE - CTE referencing another CTE

return {
  number = 4253,
  description = "CTE - CTE referencing another CTE",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees),
  EnrichedCTE AS (SELECT e.*, d.DepartmentName FROM EmpCTE e JOIN Departments d ON e.DepartmentID = d.DepartmentID)
SELECT █ FROM EnrichedCTE]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
