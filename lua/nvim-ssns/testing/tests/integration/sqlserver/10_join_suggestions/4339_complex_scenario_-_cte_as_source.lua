-- Test 4339: Complex scenario - CTE as source

return {
  number = 4339,
  description = "Complex scenario - CTE as source",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e JOIN █]],
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
