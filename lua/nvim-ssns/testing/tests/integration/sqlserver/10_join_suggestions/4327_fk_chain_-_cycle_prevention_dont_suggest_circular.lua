-- Test 4327: FK chain - cycle prevention (don't suggest circular)

return {
  number = 4327,
  description = "FK chain - cycle prevention (don't suggest circular)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d1 JOIN Departments d2 ON d1.ManagerID = d2.ManagerID JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
