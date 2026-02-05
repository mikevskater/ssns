-- Test 4135: WHERE - after OR

return {
  number = 4135,
  description = "WHERE - after OR",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = 1 OR █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
