-- Test 4015: FROM clause - multiple tables multiline

return {
  number = 4015,
  description = "FROM clause - multiple tables multiline",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e,
     Departments d,
     █]],
  expected = {
    items = {
      includes = {
        "Projects",
      },
    },
    type = "table",
  },
}
