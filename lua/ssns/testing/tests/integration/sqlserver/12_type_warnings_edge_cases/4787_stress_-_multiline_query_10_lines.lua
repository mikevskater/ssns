-- Test 4787: Stress - multiline query (10+ lines)

return {
  number = 4787,
  description = "Stress - multiline query (10+ lines)",
  database = "vim_dadbod_test",
  query = [[SELECT
  e.EmployeeID,
  e.FirstName,
  e.LastName,
  e.Salary,
  d.DepartmentName,
  p.ProjectName
FROM Employees e
INNER JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p
  ON e.EmployeeID = p.ProjectID
WHERE
  e.IsActive = 1
  AND d.Budget > 100000
  AND █]],
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "DepartmentID",
        "ProjectID",
      },
    },
    type = "column",
  },
}
