-- Test 4749: Complex - PIVOT query column

return {
  number = 4749,
  description = "Complex - PIVOT query column",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT DepartmentID, █ FROM Employees) src PIVOT (COUNT(EmployeeID) FOR DepartmentID IN ([1],[2])) pvt",
  expected = {
    items = {
      includes_any = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
