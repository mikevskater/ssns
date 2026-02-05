-- Test 4414: CTE - columns from CTE with selected columns

return {
  number = 4414,
  description = "CTE - columns from CTE with selected columns",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT █ FROM EmpCTE]],
  expected = {
    items = {
      excludes = {
        "LastName",
        "DepartmentID",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
