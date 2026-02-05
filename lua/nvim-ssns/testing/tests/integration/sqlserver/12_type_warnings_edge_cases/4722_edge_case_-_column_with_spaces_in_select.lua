-- Test 4722: Edge case - column with spaces in SELECT

return {
  number = 4722,
  description = "Edge case - column with spaces in SELECT",
  database = "vim_dadbod_test",
  query = "SELECT [First Name]█ FROM Employees",
  expected = {
    items = {
      includes_any = {
        "First Name",
        "FirstName",
      },
    },
    type = "column",
  },
}
