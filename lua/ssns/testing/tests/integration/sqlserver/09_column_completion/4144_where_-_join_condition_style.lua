-- Test 4144: WHERE - join condition style

return {
  number = 4144,
  description = "WHERE - join condition style",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d WHERE e.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
