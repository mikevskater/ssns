-- Test 4203: GROUP BY - alias-qualified

return {
  number = 4203,
  description = "GROUP BY - alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
