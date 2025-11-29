-- Test 4152: WHERE - qualified after JOIN

return {
  number = 4152,
  description = "WHERE - qualified after JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE e.█",
  expected = {
    items = {
      excludes = {
        "DepartmentName",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
