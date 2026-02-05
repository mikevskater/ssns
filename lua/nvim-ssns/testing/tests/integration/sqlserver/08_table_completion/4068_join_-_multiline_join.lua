-- Test 4068: JOIN - multiline JOIN

return {
  number = 4068,
  description = "JOIN - multiline JOIN",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e
JOIN █]],
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
