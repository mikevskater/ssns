-- Test 4249: CTE - multiple CTEs first CTE

return {
  number = 4249,
  description = "CTE - multiple CTEs first CTE",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e.█ FROM EmpCTE e, DeptCTE d]],
  expected = {
    items = {
      excludes = {
        "DepartmentName",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
