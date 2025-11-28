return {
  number = 20,
  description = [[Autocomplete for columns with multiple tables with aliases in FROM clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT

FROM
    dbo.Employees e
JOIN
    dbo.Departments d
ON
    e.DepartmentID = d.DepartmentID]],
  cursor = {
    line = 1,
    col = 4
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
      "Budget"
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
      "ProjectName",
      -- Note: Budget excluded - exists in Departments which is in query
      -- From Regions table (not in query)
      "RegionID",
      "RegionName",
      -- From Countries table (not in query)
      "CountryName",
      -- From hr.Benefits table (not in query)
      "BenefitID",
      "BenefitType",
      "Cost"
    }
  }
}