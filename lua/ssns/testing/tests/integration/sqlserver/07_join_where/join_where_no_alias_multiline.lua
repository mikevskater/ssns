return {
  number = 34,
  description = [[Autocomplete for columns after WHERE clause with multiple tables in FROM clause (Multi-line handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    *
FROM
    dbo.Employees
JOIN
    dbo.Departments ON Employees.DepartmentID = Departments.DepartmentID
WHERE]],
  cursor = {
    line = 6,
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