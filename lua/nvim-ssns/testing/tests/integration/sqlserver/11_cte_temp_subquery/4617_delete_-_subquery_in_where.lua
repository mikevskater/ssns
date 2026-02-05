-- Test 4617: DELETE - subquery in WHERE

return {
  number = 4617,
  description = "DELETE - subquery in WHERE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[DELETE FROM Employees
WHERE DepartmentID IN (SELECT █ FROM Departments WHERE IsActive = 0)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
