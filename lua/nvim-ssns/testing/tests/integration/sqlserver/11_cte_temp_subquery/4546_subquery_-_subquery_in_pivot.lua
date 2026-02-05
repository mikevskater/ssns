-- Test 4546: Subquery - subquery in PIVOT

return {
  number = 4546,
  description = "Subquery - subquery in PIVOT",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM (SELECT █ FROM Employees) src
PIVOT (COUNT(EmployeeID) FOR DepartmentID IN ([1], [2], [3])) pvt]],
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
