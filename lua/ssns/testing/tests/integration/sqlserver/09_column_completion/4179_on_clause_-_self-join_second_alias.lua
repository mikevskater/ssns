-- Test 4179: ON clause - self-join second alias

return {
  number = 4179,
  description = "ON clause - self-join second alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Employees m ON m.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "ManagerID",
      },
    },
    type = "column",
  },
}
