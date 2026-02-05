-- Test 4437: CTE - CTE inside CTE definition not visible outside
-- SKIPPED: CTE name completion not yet supported

return {
  number = 4437,
  description = "CTE - CTE inside CTE definition not visible outside",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH Outer AS (
  SELECT * FROM Employees
)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "Outer",
      },
    },
    type = "table",
  },
}
