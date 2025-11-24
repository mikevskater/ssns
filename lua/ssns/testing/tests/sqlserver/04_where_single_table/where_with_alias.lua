return {
  number = 15,
  description = [[Autocomplete for columns in WHERE clause with table alias]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES e WHERE e.]],
  cursor = {
    line = 0,
    col = 38
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