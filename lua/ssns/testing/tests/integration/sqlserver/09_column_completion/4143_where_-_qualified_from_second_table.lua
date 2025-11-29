-- Test 4143: WHERE - qualified from second table

return {
  number = 4143,
  description = "WHERE - qualified from second table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d WHERE d.█",
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
