-- Test 4594: UPDATE - multiple tables WHERE
-- SKIPPED: Alias-qualified column completion in UPDATE WHERE not yet supported

return {
  number = 4594,
  description = "UPDATE - multiple tables WHERE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[UPDATE e
SET e.DeptName = d.DepartmentName
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE d.█]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "Budget",
      },
    },
    type = "column",
  },
}
