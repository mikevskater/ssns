-- Test 4245: OUTER APPLY - columns

return {
  number = 4245,
  description = "OUTER APPLY - columns",
  database = "vim_dadbod_test",
  query = "SELECT e.FirstName, details.█ FROM Employees e OUTER APPLY (SELECT TOP 1 * FROM Projects) AS details",
  expected = {
    items = {
      includes_any = {
        "ProjectName",
        "ProjectID",
      },
    },
    type = "column",
  },
}
