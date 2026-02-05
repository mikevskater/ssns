-- Test 4306: FK suggestion - self-referential (Departments.ManagerID -> Employees)

return {
  number = 4306,
  description = "FK suggestion - self-referential (Departments.ManagerID -> Employees)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
