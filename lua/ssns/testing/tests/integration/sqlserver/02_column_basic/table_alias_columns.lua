return {
  number = 7,
  description = [[Autocomplete for table columns]],
  database = [[vim_dadbod_test]],
  query = [[SELECT e. FROM dbo.EMPLOYEES e]],
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