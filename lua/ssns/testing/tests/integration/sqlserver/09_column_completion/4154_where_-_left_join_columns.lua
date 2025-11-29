-- Test 4154: WHERE - LEFT JOIN columns

return {
  number = 4154,
  description = "WHERE - LEFT JOIN columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
