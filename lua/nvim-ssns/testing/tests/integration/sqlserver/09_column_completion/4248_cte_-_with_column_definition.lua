-- Test 4248: CTE - with column definition

return {
  number = 4248,
  description = "CTE - with column definition",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE (ID, Name) AS (SELECT EmployeeID, FirstName FROM Employees)
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
