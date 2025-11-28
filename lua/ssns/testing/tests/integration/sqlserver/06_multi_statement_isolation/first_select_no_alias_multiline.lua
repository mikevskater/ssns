return {
  number = 26,
  description = [[Autocomplete for columns in select with multiple select statements in query (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    
FROM
    dbo.EMPLOYEES;

SELECT
    *
FROM
    dbo.DEPARTMENTS;]],
  cursor = {
    line = 1,
    col = 4
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