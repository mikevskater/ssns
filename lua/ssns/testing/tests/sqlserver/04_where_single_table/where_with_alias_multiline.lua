return {
  number = 16,
  description = [[Autocomplete for columns after WHERE clause with table alias (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES e 
WHERE 
    e.]],
  cursor = {
    line = 2,
    col = 6
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