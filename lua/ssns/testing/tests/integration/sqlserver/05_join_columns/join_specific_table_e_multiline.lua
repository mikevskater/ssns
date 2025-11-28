return {
  number = 23,
  description = [[Autocomplete for columns with multiple tables in FROM clause with aliases and table specified (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    e.
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
      -- From Departments table (not requested - cursor is on "e")
      "DepartmentName",
      "ManagerID",
      "Budget",
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