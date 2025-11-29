-- Test 4206: GROUP BY - multiline

return {
  number = 4206,
  description = "GROUP BY - multiline",
  database = "vim_dadbod_test",
  query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY █]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
