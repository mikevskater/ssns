-- Test 4124: SELECT - alias-qualified from multiple tables

return {
  number = 4124,
  description = "SELECT - alias-qualified from multiple tables",
  database = "vim_dadbod_test",
  query = "SELECT e.█ FROM Employees e, Departments d",
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
