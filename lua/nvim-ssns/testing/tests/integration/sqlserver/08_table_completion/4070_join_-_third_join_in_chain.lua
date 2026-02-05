-- Test 4070: JOIN - third JOIN in chain

return {
  number = 4070,
  description = "JOIN - third JOIN in chain",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.DepartmentID = d.DepartmentID
JOIN █]],
  expected = {
    items = {
      includes = {
        "Customers",
        "Orders",
      },
    },
    type = "table",
  },
}
