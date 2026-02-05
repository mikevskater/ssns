-- Test 4121: SELECT - columns from multiple tables (unqualified)

return {
  number = 4121,
  description = "SELECT - columns from multiple tables (unqualified)",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees, Departments",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
