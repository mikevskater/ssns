-- Test 4379: ON clause - with BETWEEN operator

return {
  number = 4379,
  description = "ON clause - with BETWEEN operator",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Projects p ON e.HireDate BETWEEN p.█]],
  expected = {
    items = {
      includes_any = {
        "StartDate",
        "EndDate",
      },
    },
    type = "column",
  },
}
