return {
  number = 29,
  description = [[Autocomplete for columns in select with multiple select statements in query with same aliases]],
  database = [[vim_dadbod_test]],
  query = [[SELECT e.█ FROM dbo.Employees e
SELECT * FROM dbo.Departments e]],
  expected = {
    type = [[column]],
    includes = {
      -- From Employees (current statement with alias 'e')
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "DepartmentID",
      "HireDate",
      "Salary",
      "IsActive"
    },
    excludes = {
      -- From Departments (different statement - alias 'e' means different table there)
      "DepartmentName",
      "ManagerID",
      "Budget",
      -- From other tables (not in query at all)
      "OrderId",
      "OrderDate",
      "Total",
      "Status",
      "CustomerId",
      "CompanyId",
      "Country",
      "CountryID",
      "ProductId",
      "CategoryId",
      "Price",
      "ProjectID",
      "ProjectName"
    }
  }
}