return {
  number = 31,
  description = [[Autocomplete for columns in second select with multiple select statements in query with same aliases]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES e
SELECT e. FROM dbo.DEPARTMENTS e]],
  cursor = {
    line = 1,
    col = 9
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