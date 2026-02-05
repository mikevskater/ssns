-- Test 4607: DELETE - alias in WHERE
-- SKIPPED: Alias-qualified column completion in DELETE WHERE not yet supported

return {
  number = 4607,
  description = "DELETE - alias in WHERE",
  database = "vim_dadbod_test",
  skip = false,
  query = "DELETE e FROM Employees e WHERE e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
