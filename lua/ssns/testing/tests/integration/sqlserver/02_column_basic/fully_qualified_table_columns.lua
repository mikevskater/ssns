return {
  number = 6,
  description = [[Autocomplete for colums in table (Fully qualified table name)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT dbo.Employees. FROM  dbo.Employees]],
  cursor = {
    line = 0,
    col = 21
  },
  expected = {
    type = [[table]],
    items = {
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "DepartmentID",
      "HireDate",
      "Salary",
      "IsActive"
    }
  }
}