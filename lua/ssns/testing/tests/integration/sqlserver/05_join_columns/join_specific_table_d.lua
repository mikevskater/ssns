return {
  number = 22,
  description = [[Autocomplete for columns with multiple tables in FROM clause with aliases and table specified]],
  database = [[vim_dadbod_test]],
  query = [[SELECT e.FirstName, d. FROM dbo.EMPLOYEES e JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID]],
  cursor = {
    line = 0,
    col = 22
  },
  expected = {
    type = [[column]],
    items = {
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    }
  }
}