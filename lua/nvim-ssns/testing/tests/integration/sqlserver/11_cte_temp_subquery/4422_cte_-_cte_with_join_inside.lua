-- Test 4422: CTE - CTE with JOIN inside

return {
  number = 4422,
  description = "CTE - CTE with JOIN inside",
  database = "vim_dadbod_test",
  query = [[WITH EmpDept AS (SELECT e.EmployeeID, e.FirstName, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID)
SELECT █ FROM EmpDept]],
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
