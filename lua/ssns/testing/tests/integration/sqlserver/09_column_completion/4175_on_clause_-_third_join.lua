-- Test 4175: ON clause - third JOIN

return {
  number = 4175,
  description = "ON clause - third JOIN",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.DepartmentID = d.DepartmentID
JOIN Customers c ON c.Id = █]],
  expected = {
    items = {
      includes = {
        "Id",
        "CustomerId",
      },
    },
    type = "column",
  },
}
