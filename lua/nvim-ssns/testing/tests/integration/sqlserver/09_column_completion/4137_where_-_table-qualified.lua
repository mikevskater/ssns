-- Test 4137: WHERE - table-qualified

return {
  number = 4137,
  description = "WHERE - table-qualified",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Employees.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
