-- Test 4343: CROSS JOIN - no ON clause needed

return {
  number = 4343,
  description = "CROSS JOIN - no ON clause needed",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e CROSS JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
