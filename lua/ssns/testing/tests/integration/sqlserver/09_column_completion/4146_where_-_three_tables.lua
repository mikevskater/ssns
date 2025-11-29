-- Test 4146: WHERE - three tables

return {
  number = 4146,
  description = "WHERE - three tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d, Projects p WHERE p.█",
  expected = {
    items = {
      excludes = {
        "FirstName",
        "DepartmentName",
      },
      includes = {
        "ProjectID",
        "ProjectName",
      },
    },
    type = "column",
  },
}
