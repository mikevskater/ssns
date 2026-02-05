return {
  number = 9,
  description = [[Autocomplete for table columns (Multi-line SELECT handling with alias)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
    e.█
FROM
    dbo.EMPLOYEES e;]],
  expected = {
    type = [[column]],
    items = {
      "EmployeeID",
      "FirstName",
      "LastName",
      "Email",
      "DepartmentID",
      "HireDate",
      "Salary",
      "IsActive"
    }
  }
}