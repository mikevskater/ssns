-- Test 4209: GROUP BY - with prefix filter

return {
  number = 4209,
  description = "GROUP BY - with prefix filter",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY Dep█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
