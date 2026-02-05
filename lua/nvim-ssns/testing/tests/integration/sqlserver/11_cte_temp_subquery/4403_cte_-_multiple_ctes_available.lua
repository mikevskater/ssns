-- Test 4403: CTE - multiple CTEs available

return {
  number = 4403,
  description = "CTE - multiple CTEs available",
  database = "vim_dadbod_test",
  query = [[WITH
  EmpCTE AS (SELECT * FROM Employees),
  DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "EmpCTE",
        "DeptCTE",
        "Employees",
      },
    },
    type = "table",
  },
}
