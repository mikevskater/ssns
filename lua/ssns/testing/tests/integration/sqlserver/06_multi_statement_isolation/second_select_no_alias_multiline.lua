return {
  number = 28,
  description = [[Autocomplete for columns in second select with multiple select statements in query (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    *
FROM
    dbo.Employees;
SELECT
    █
FROM
    dbo.Departments;]],
  expected = {
    type = [[column]],
    includes = {
      -- From Departments (current statement)
      "DepartmentID",
      "DepartmentName",
      "ManagerID",
      "Budget",
      -- Scalar functions (available for unqualified SELECT)
      "dbo.fn_GetEmployeeFullName",
      "dbo.fn_CalculateYearsOfService",
      "hr.fn_GetTotalBenefitCost"
    },
    excludes = {
      -- From Employees (different statement - should be isolated)
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "HireDate",
      "Salary",
      "IsActive",
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