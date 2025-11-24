return {
  number = 39,
  description = [[Autocomplete for columns after WHERE clause with multiple tables with aliases in FROM clause with table specified]],
  database = [[vim_dadbod_test]],
  query = [[SELECT d.*, e.FirstName FROM dbo.EMPLOYEES e JOIN dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID WHERE d.]],
  cursor = {
    line = 0,
    col = 111
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