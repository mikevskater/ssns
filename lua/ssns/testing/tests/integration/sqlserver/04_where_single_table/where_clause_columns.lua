return {
  number = 11,
  description = [[Autocomplete for columns after WHERE clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES WHERE]],
  cursor = {
    line = 0,
    col = 34
  },
  expected = {
    type = [[column]],
    includes = {
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
      -- From Departments table
      "DepartmentName",
      "ManagerID",
      "Budget",
      -- From Orders table
      "OrderId",
      "CustomerId",
      "ProductId",
      "OrderDate",
      "Total",
      "TotalAmount",
      "Status",
      -- From Customers table
      "Name",
      "CompanyId",
      "Country",
      "Active",
      "CreatedDate",
      -- From Products table
      "Price",
      "CategoryId",
      "SupplierId",
      "Sales",
      "Discontinued"
    }
  }
}