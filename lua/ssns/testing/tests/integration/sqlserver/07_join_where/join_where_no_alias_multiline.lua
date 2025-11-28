return {
  number = 34,
  description = [[Autocomplete for columns after WHERE clause with multiple tables in FROM clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    *
FROM
    dbo.EMPLOYEES
JOIN
    dbo.DEPARTMENTS ON EMPLOYEES.DepartmentID = DEPARTMENTS.DepartmentID
WHERE]],
  cursor = {
    line = 6,
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
      "IsActive",
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    }
  }
}