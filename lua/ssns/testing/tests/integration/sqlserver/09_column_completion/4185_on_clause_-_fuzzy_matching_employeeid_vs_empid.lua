-- Test 4185: ON clause - fuzzy matching EmployeeID vs EmpID

return {
  number = 4185,
  description = "ON clause - fuzzy matching EmployeeID vs EmpID",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.█",
  expected = {
    items = {
      includes_any = {
        "EmployeeId",
      },
    },
    type = "column",
  },
}
