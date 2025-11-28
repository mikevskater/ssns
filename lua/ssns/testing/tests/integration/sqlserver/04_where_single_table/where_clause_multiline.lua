return {
  number = 12,
  description = [[Autocomplete for columns after WHERE clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES 
WHERE]],
  cursor = {
    line = 1,
    col = 4
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