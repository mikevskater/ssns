-- Test 4126: SELECT - mixing qualified and unqualified

return {
  number = 4126,
  description = "SELECT - mixing qualified and unqualified",
  database = "vim_dadbod_test",
  query = "SELECT e.EmployeeID, █ FROM Employees e, Departments d",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "DepartmentName",
        "FirstName",
      },
    },
    type = "column",
  },
}
