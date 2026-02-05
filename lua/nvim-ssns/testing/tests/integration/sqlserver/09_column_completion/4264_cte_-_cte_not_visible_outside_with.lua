-- Test 4264: CTE - CTE not visible outside WITH

return {
  number = 4264,
  description = "CTE - CTE not visible outside WITH",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █EmpCTE",
  expected = {
    items = {
      excludes = {
        "EmpCTE",
      },
    },
    type = "table",
  },
}
