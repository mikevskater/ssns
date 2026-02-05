-- Test 4413: CTE - columns from CTE with explicit column list

return {
  number = 4413,
  description = "CTE - columns from CTE with explicit column list",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE (ID, Name, Dept) AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees)
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
        "Dept",
      },
    },
    type = "column",
  },
}
