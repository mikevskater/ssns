-- Test 4420: CTE - columns in WHERE with CTE

return {
  number = 4420,
  description = "CTE - columns in WHERE with CTE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE WHERE █]],
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
