-- Test 4427: CTE - CTE with UNION

return {
  number = 4427,
  description = "CTE - CTE with UNION",
  database = "vim_dadbod_test",
  query = [[WITH Combined AS (
  SELECT EmployeeID AS ID, FirstName AS Name FROM Employees
  UNION ALL
  SELECT Id AS ID, Name AS Name FROM Customers
)
SELECT █ FROM Combined]],
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
