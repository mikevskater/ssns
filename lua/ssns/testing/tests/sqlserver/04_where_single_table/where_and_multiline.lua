return {
  number = 14,
  description = [[Autocomplete for columns after AND clause in WHERE statement (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES 
WHERE 
    IsActive = 1 
    AND]],
  cursor = {
    line = 3,
    col = 8
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