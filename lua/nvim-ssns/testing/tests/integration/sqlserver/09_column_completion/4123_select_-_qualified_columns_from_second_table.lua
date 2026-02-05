-- Test 4123: SELECT - qualified columns from second table

return {
  number = 4123,
  description = "SELECT - qualified columns from second table",
  database = "vim_dadbod_test",
  query = "SELECT Departments.█ FROM Employees, Departments",
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
