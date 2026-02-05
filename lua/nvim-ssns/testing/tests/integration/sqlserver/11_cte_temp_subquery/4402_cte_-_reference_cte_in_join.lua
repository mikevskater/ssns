-- Test 4402: CTE - reference CTE in JOIN

return {
  number = 4402,
  description = "CTE - reference CTE in JOIN",
  database = "vim_dadbod_test",
  query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM Employees e JOIN █]],
  expected = {
    items = {
      includes = {
        "DeptCTE",
        "Departments",
      },
    },
    type = "table",
  },
}
