return {
  number = 39,
  description = [[Autocomplete for columns after WHERE clause with multiple tables with aliases in FROM clause with table specified]],
  database = [[vim_dadbod_test]],
  query = [[SELECT d.*, e.FirstName FROM dbo.Employees e JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID WHERE d.█]],
  expected = {
    type = [[column]],
    includes = {
      -- From Departments only (cursor after "d.")
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget"
    },
    excludes = {
      -- From Employees (not qualified with d.)
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "HireDate",
      "Salary",
      "IsActive",
      -- From other tables
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