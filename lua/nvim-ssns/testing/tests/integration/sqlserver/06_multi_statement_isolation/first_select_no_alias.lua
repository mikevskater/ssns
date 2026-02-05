return {
  number = 25,
  description = [[Autocomplete for columns in select with multiple select statements in query]],
  database = [[vim_dadbod_test]],
  query = [[SELECT █ FROM dbo.Employees
SELECT * FROM dbo.Departments]],
  expected = {
    type = [[column]],
    includes = {
      -- From Employees (current statement)
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "DepartmentID",
      "HireDate",
      "Salary",
      "IsActive",
      -- Scalar functions (available for unqualified SELECT)
      "dbo.fn_GetEmployeeFullName",
      "dbo.fn_CalculateYearsOfService",
      "hr.fn_GetTotalBenefitCost"
    },
    excludes = {
      -- From Departments (different statement - should be isolated)
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