-- Test 4618: DELETE - EXISTS subquery

return {
  number = 4618,
  description = "DELETE - EXISTS subquery",
  database = "vim_dadbod_test",
  query = [[DELETE FROM Departments d
WHERE NOT EXISTS (SELECT 1 FROM Employees e WHERE e.DepartmentID = d.█)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
