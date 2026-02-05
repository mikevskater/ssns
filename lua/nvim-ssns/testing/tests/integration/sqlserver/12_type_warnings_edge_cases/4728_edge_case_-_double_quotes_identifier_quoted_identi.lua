-- Test 4728: Edge case - double quotes identifier (QUOTED_IDENTIFIER)

return {
  number = 4728,
  description = "Edge case - double quotes identifier (QUOTED_IDENTIFIER)",
  database = "vim_dadbod_test",
  query = "SELECT \"FirstName\"█ FROM Employees",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
