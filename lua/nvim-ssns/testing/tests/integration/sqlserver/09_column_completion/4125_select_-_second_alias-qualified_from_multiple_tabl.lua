-- Test 4125: SELECT - second alias-qualified from multiple tables

return {
  number = 4125,
  description = "SELECT - second alias-qualified from multiple tables",
  database = "vim_dadbod_test",
  query = "SELECT d.█ FROM Employees e, Departments d",
  expected = {
    items = {
      excludes = {
        "FirstName",
      },
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
