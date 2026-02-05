-- Test 4307: FK suggestion - Departments suggested for Employees join
-- Tests that Departments is suggested when joining from Employees (FK relationship)

return {
  number = 4307,
  description = "FK suggestion - Departments suggested for Employees join",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
