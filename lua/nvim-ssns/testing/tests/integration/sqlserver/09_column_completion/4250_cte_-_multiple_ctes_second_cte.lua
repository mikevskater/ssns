-- Test 4250: CTE - multiple CTEs second CTE

return {
  number = 4250,
  description = "CTE - multiple CTEs second CTE",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT d.█ FROM EmpCTE e, DeptCTE d]],
  expected = {
    items = {
      excludes = {
        "FirstName",
      },
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
