-- Test 4581: UPDATE - SET from joined table
-- SKIPPED: Alias-qualified column completion in UPDATE SET not yet supported

return {
  number = 4581,
  description = "UPDATE - SET from joined table",
  database = "vim_dadbod_test",
  skip = false,
  query = "UPDATE e SET e.DeptName = d.█ FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
  expected = {
    items = {
      includes = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
