return {
  number = 11,
  description = [[Autocomplete for columns after WHERE clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES WHERE]],
  cursor = {
    line = 0,
    col = 34
  },
  expected = {
    type = [[column]],
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