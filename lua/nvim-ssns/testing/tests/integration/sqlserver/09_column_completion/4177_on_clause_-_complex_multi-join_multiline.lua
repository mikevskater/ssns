-- Test 4177: ON clause - complex multi-join multiline

return {
  number = 4177,
  description = "ON clause - complex multi-join multiline",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
INNER JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p
  ON d.DepartmentID = p.DepartmentID
  AND p.█ > 0]],
  expected = {
    items = {
      includes = {
        "Budget",
        "ProjectID",
      },
    },
    type = "column",
  },
}
