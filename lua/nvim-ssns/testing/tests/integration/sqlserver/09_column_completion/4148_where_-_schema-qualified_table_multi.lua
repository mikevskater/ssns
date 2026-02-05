-- Test 4148: WHERE - schema-qualified table multi

return {
  number = 4148,
  description = "WHERE - schema-qualified table multi",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e, dbo.Departments d WHERE e.█",
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
