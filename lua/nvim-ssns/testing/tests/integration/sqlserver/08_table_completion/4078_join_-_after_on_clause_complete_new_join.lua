-- Test 4078: JOIN - after ON clause complete, new JOIN

return {
  number = 4078,
  description = "JOIN - after ON clause complete, new JOIN",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT JOIN █]],
  expected = {
    items = {
      includes = {
        "Projects",
      },
    },
    type = "table",
  },
}
