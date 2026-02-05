-- Test 4398: ON clause - mixed case

return {
  number = 4398,
  description = "ON clause - mixed case",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees E JOIN Departments D ON E.departmentid = D.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
