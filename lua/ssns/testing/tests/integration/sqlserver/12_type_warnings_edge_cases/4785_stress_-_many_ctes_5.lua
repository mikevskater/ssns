-- Test 4785: Stress - many CTEs (5+)

return {
  number = 4785,
  description = "Stress - many CTEs (5+)",
  database = "vim_dadbod_test",
  query = "WITH CTE1 AS (SELECT 1 AS A), CTE2 AS (SELECT 2 AS B), CTE3 AS (SELECT 3 AS C), CTE4 AS (SELECT 4 AS D), CTE5 AS (SELECT 5 AS E) SELECT * F█ROM ",
  expected = {
    items = {
      includes = {
        "CTE1",
        "CTE2",
        "CTE3",
        "CTE4",
        "CTE5",
      },
    },
    type = "table",
  },
}
