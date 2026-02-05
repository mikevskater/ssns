-- Test 4178: ON clause - self-join

return {
  number = 4178,
  description = "ON clause - self-join",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Employees m ON e.ManagerID = m.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
