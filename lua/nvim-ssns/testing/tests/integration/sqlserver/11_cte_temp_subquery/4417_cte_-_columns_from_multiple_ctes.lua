-- Test 4417: CTE - columns from multiple CTEs

return {
  number = 4417,
  description = "CTE - columns from multiple CTEs",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e.█, d. FROM EmpCTE e, DeptCTE d]],
  expected = {
    items = {
      excludes = {
        "DepartmentID",
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
