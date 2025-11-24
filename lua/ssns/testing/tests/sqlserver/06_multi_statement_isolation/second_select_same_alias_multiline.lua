return {
  number = 32,
  description = [[Autocomplete for columns in second select with multiple select statements in query with same aliases (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    *
FROM
    dbo.EMPLOYEES e;
SELECT
    e.
FROM
    dbo.DEPARTMENTS e;]],
  cursor = {
    line = 5,
    col = 6
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