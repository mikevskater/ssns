return {
  number = 28,
  description = [[Autocomplete for columns in second select with multiple select statements in query (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    *
FROM
    dbo.EMPLOYEES;
SELECT
    
FROM
    dbo.DEPARTMENTS;]],
  cursor = {
    line = 5,
    col = 4
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