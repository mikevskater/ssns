-- Test 4418: CTE - columns from second CTE

return {
  number = 4418,
  description = "CTE - columns from second CTE",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e.EmployeeID, d.█ FROM EmpCTE e, DeptCTE d]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
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
