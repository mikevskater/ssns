-- Test 4151: WHERE - after JOIN

return {
  number = 4151,
  description = "WHERE - after JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
