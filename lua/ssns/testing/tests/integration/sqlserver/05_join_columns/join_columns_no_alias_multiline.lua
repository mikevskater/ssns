return {
  number = 18,
  description = [[Autocomplete for columns with multiple tables in FROM clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
    
FROM
    dbo.EMPLOYEES
    JOIN dbo.DEPARTMENTS ON EMPLOYEES.DepartmentID = DEPARTMENTS.DepartmentID]],
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