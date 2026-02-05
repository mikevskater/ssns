-- Test 4188: ON clause - date type compatibility

return {
  number = 4188,
  description = "ON clause - date type compatibility",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.█",
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
