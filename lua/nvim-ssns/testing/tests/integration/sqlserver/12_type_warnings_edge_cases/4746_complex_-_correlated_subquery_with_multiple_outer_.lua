-- Test 4746: Complex - correlated subquery with multiple outer refs

return {
  number = 4746,
  description = "Complex - correlated subquery with multiple outer refs",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees e
WHERE EXISTS (
  SELECT 1 FROM Departments d
  WHERE d.DepartmentID = e.DepartmentID
  AND d.ManagerID = e.█
)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
