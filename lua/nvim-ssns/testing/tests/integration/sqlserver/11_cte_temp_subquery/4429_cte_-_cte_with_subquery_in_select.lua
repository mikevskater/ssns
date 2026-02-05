-- Test 4429: CTE - CTE with subquery in SELECT

return {
  number = 4429,
  description = "CTE - CTE with subquery in SELECT",
  database = "vim_dadbod_test",
  query = [[WITH EmpWithDept AS (SELECT EmployeeID, (SELECT DepartmentName FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName FROM Employees e)
SELECT █ FROM EmpWithDept]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DeptName",
      },
    },
    type = "column",
  },
}
