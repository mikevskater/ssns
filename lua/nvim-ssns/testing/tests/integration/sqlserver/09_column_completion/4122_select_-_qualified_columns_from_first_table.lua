-- Test 4122: SELECT - qualified columns from first table

return {
  number = 4122,
  description = "SELECT - qualified columns from first table",
  database = "vim_dadbod_test",
  query = "SELECT Employees.█ FROM Employees, Departments",
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
