-- Test 4545: Subquery - correlated with multiple outer references

return {
  number = 4545,
  description = "Subquery - correlated with multiple outer references",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = d.█ AND DepartmentID = e.DepartmentID)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
