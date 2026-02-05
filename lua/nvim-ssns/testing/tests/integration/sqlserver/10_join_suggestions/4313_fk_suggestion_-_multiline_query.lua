-- Test 4313: FK suggestion - multiline query

return {
  number = 4313,
  description = "FK suggestion - multiline query",
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
    type = "join_suggestion",
  },
}
