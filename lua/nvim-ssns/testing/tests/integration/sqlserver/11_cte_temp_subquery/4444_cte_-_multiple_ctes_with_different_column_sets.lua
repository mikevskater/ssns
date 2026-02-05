-- Test 4444: CTE - multiple CTEs with different column sets

return {
  number = 4444,
  description = "CTE - multiple CTEs with different column sets",
  database = "vim_dadbod_test",
  query = [[WITH
  Emp AS (SELECT EmployeeID, FirstName FROM Employees),
  Dept AS (SELECT DepartmentID, DepartmentName FROM Departments),
  Proj AS (SELECT ProjectID, ProjectName FROM Projects)
SELECT e.EmployeeID, d.DepartmentName, p.█ FROM Emp e, Dept d, Proj p]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
        "DepartmentName",
      },
      includes = {
        "ProjectID",
        "ProjectName",
      },
    },
    type = "column",
  },
}
