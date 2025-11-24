return {
  number = 38,
  description = [[Autocomplete for columns after WHERE clause with multiple tables with aliases in FROM clause with table specified (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    d.DepartmentName, 
    e.*
FROM
    dbo.EMPLOYEES e
JOIN
    dbo.DEPARTMENTS d ON e.DepartmentID = d.DepartmentID
WHERE
    e.]],
  cursor = {
    line = 8,
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