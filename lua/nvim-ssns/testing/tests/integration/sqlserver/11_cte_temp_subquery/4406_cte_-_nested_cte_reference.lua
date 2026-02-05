-- Test 4406: CTE - nested CTE reference

return {
  number = 4406,
  description = "CTE - nested CTE reference",
  database = "vim_dadbod_test",
  query = [[WITH
  Base AS (SELECT * FROM Employees),
  Derived AS (SELECT * FROM Base)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "Base",
        "Derived",
      },
    },
    type = "table",
  },
}
