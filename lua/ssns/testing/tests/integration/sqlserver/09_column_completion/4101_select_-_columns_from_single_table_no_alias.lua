-- Test 4101: SELECT - columns from single table (no alias)

return {
  number = 4101,
  description = "SELECT - columns from single table (no alias)",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "Email",
        "DepartmentID",
        "Salary",
        "HireDate",
        "IsActive",
      },
    },
    type = "column",
  },
}
