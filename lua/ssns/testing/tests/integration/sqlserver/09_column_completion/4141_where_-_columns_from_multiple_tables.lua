-- Test 4141: WHERE - columns from multiple tables

return {
  number = 4141,
  description = "WHERE - columns from multiple tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
