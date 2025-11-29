-- Test 4199: ORDER BY - multiline

return {
  number = 4199,
  description = "ORDER BY - multiline",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees
ORDER BY █]],
  expected = {
    items = {
      includes = {
        "LastName",
        "FirstName",
      },
    },
    type = "column",
  },
}
