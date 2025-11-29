-- Test 4232: Subquery - columns in WHERE subquery

return {
  number = 4232,
  description = "Subquery - columns in WHERE subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT  FR█OM Departments)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
