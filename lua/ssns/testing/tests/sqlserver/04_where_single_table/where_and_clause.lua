return {
  number = 13,
  description = [[Autocomplete for columns after AND clause in WHERE statement]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES WHERE IsActive = 1 AND]],
  cursor = {
    line = 0,
    col = 51
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