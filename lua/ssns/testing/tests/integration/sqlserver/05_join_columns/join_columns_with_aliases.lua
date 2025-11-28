return {
  number = 19,
  description = [[Autocomplete for columns with multiple tables with aliases in FROM clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT  FROM dbo.EMPLOYEES e JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
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
      "IsActive",
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    }
  }
}