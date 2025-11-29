-- Test 4142: WHERE - qualified from first table

return {
  number = 4142,
  description = "WHERE - qualified from first table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d WHERE e.█",
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
