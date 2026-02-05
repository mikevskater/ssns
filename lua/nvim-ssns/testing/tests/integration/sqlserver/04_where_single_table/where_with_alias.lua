return {
  number = 15,
  description = [[Autocomplete for columns in WHERE clause with table alias]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.EMPLOYEES e WHERE e.█]],
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