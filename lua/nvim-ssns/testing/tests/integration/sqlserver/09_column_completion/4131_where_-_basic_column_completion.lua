-- Test 4131: WHERE - basic column completion

return {
  number = 4131,
  description = "WHERE - basic column completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
