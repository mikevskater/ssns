-- Test 4415: CTE - columns from CTE with aliased columns

return {
  number = 4415,
  description = "CTE - columns from CTE with aliased columns",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees)
SELECT █ FROM EmpCTE]],
  expected = {
    items = {
      excludes = {
        "EmployeeID",
        "FirstName",
      },
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
