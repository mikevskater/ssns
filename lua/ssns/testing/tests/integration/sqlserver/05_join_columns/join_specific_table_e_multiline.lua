return {
  number = 23,
  description = [[Autocomplete for columns with multiple tables in FROM clause with aliases and table specified (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    e.
FROM
    dbo.EMPLOYEES e
JOIN
    dbo.DEPARTMENTS d
ON
    e.DepartmentID = d.DepartmentID]],
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