return {
  number = 30,
  description = [[Autocomplete for columns in select with multiple select statements in query with same aliases (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    e.
FROM
    dbo.EMPLOYEES e;
SELECT
    *
FROM
    dbo.DEPARTMENTS e;]],
  cursor = {
    line = 1,
    col = 6
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