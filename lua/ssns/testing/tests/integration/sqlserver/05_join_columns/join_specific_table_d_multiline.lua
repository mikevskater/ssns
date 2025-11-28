return {
  number = 24,
  description = [[Autocomplete for columns with multiple tables in FROM clause with aliases and table specified (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    d.
FROM
    dbo.Employees e
JOIN
    dbo.Departments d
ON
    e.DepartmentID = d.DepartmentID]],
  cursor = {
    line = 1,
    col = 6
  },
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
      -- From Employees table (not requested - cursor is on "d")
      "EmployeeID",
      "FirstName",
      "LastName",
      "HireDate",
      "Salary",
      "IsActive",
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