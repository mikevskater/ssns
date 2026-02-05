-- Test 4524: Subquery - subquery in UNION

return {
  number = 4524,
  description = "Subquery - subquery in UNION",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM (
  SELECT EmployeeID AS ID, FirstName AS Name FROM Employees
  UNION ALL
  SELECT Id AS ID, Name AS Name FROM Customers
) combined WHERE █]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
