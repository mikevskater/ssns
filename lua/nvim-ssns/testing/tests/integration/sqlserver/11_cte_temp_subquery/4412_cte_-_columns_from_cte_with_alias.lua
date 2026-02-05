-- Test 4412: CTE - columns from CTE with alias

return {
  number = 4412,
  description = "CTE - columns from CTE with alias",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT e.█ FROM EmpCTE e]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
