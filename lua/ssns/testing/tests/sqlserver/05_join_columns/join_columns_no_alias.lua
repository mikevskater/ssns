return {
  number = 17,
  description = [[Autocomplete for columns with multiple tables in FROM clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT  FROM dbo.EMPLOYEES JOIN dbo.DEPARTMENTS ON EMPLOYEES.DepartmentID = DEPARTMENTS.DepartmentID]],
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