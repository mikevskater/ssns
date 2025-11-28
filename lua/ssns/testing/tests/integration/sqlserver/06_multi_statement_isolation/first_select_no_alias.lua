return {
  number = 25,
  description = [[Autocomplete for columns in select with multiple select statements in query]],
  database = [[vim_dadbod_test]],
  query = [[SELECT  FROM dbo.EMPLOYEES
SELECT * FROM dbo.DEPARTMENTS]],
  cursor = {
    line = 0,
    col = 7
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