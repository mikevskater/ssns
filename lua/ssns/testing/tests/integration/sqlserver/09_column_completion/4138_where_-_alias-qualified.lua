-- Test 4138: WHERE - alias-qualified

return {
  number = 4138,
  description = "WHERE - alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE e.█",
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
