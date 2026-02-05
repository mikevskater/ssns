return {
  number = 7,
  description = [[Autocomplete for table columns]],
  database = [[vim_dadbod_test]],
  query = [[SELECT e.█ FROM dbo.EMPLOYEES e]],
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