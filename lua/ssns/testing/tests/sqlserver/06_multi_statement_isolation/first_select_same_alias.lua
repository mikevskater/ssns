return {
  number = 29,
  description = [[Autocomplete for columns in select with multiple select statements in query with same aliases]],
  database = [[vim_dadbod_test]],
  query = [[SELECT e. FROM dbo.EMPLOYEES e
SELECT * FROM dbo.DEPARTMENTS e]],
  cursor = {
    line = 0,
    col = 9
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