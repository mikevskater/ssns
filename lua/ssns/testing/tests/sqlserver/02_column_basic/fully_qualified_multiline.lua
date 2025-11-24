return {
  number = 8,
  description = [[Autocomplete for colums in table (Fully qualified table name Multi-line SELECT handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    dbo.Employees.
FROM  
    dbo.Employees;]],
  cursor = {
    line = 1,
    col = 18
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