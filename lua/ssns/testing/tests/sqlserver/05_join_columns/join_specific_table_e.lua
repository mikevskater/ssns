return {
  number = 21,
  description = [[Autocomplete for columns with multiple tables in FROM clause with aliases and table specified]],
  database = [[vim_dadbod_test]],
  query = [[SELECT d.DepartmentName, e. FROM dbo.EMPLOYEES e JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
  cursor = {
    line = 0,
    col = 27
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