-- Test 4548: Subquery - VALUES as derived table
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4548,
  description = "Subquery - VALUES as derived table",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT v.█ FROM (VALUES (1, 'A'), (2, 'B'), (3, 'C')) AS v(ID, Letter)",
  expected = {
    items = {
      includes = {
        "ID",
        "Letter",
      },
    },
    type = "column",
  },
}
