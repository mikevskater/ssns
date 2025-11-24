return {
  number = 27,
  description = [[Autocomplete for columns in second select with multiple select statements in query]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES
SELECT  FROM dbo.DEPARTMENTS]],
  cursor = {
    line = 1,
    col = 7
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