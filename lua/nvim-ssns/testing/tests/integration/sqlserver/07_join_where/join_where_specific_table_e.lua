return {
  number = 37,
  description = [[Autocomplete for columns after WHERE clause with multiple tables with aliases in FROM clause with table specified]],
  database = [[vim_dadbod_test]],
  query = [[SELECT d.DepartmentName, e.* FROM dbo.Employees e JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID WHERE e.█]],
  expected = {
    type = [[column]],
    includes = {
      -- From Employees only (cursor after "e.")
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
      -- From Departments (not qualified with e.)
      "DepartmentName",
      "ManagerID",
      "Budget",
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