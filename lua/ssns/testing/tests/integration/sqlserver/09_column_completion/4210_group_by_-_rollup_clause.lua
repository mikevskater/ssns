-- Test 4210: GROUP BY - ROLLUP clause

return {
  number = 4210,
  description = "GROUP BY - ROLLUP clause",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY ROLLUP()█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
