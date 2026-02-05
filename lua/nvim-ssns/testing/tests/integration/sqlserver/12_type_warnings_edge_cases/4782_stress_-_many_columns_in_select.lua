-- Test 4782: Stress - many columns in SELECT
-- SKIPPED: Test table WideTable does not exist in database

return {
  number = 4782,
  description = "Stress - many columns in SELECT",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Test table WideTable does not exist in database",
  query = "SELECT Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8, Col9, Col10, Col11, Col12, Col13, Col14, Col15, Col16, Col17, Col18, Col19, Col20,█  FROM WideTable",
  expected = {
    items = {
      includes_any = {
        "Col21",
        "Col22",
      },
    },
    type = "column",
  },
}
