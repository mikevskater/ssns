return {
  number = 20,
  description = [[Autocomplete for columns with multiple tables with aliases in FROM clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    
FROM
    dbo.EMPLOYEES e
JOIN 
    dbo.DEPARTMENTS d 
ON 
    e.DepartmentID = d.DepartmentID]],
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
      "IsActive",
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    }
  }
}