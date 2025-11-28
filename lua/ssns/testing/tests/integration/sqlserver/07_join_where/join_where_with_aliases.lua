return {
  number = 35,
  description = [[Autocomplete for columns after WHERE clause with multiple tables with aliases in FROM clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.DepartmentID = d.DepartmentID WHERE]],
  cursor = {
    line = 0,
    col = 94
  },
  expected = {
    type = [[column]],
    includes = {
      -- From Employees
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "DepartmentID",
      "HireDate",
      "Salary",
      "IsActive",
      -- From Departments
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget",
      -- Scalar functions (available in unqualified WHERE)
      "dbo.fn_GetEmployeeFullName",
      "dbo.fn_CalculateYearsOfService",
      "hr.fn_GetTotalBenefitCost"
    },
    excludes = {
      -- From Orders table (not in query)
      "OrderId",
      "OrderDate",
      "Total",
      "Status",
      -- From Customers table (not in query)
      "CustomerId",
      "CompanyId",
      "Country",
      "CountryID",
      -- From Products table (not in query)
      "ProductId",
      "CategoryId",
      "Price",
      -- From Projects table (not in query)
      "ProjectID",
      "ProjectName"
    }
  }
}