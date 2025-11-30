-- Test 4071: JOIN - tables available after JOIN
-- Note: FK-based join suggestions (with auto ON clause) is a future enhancement.
-- Currently returns all tables; Departments is included since it exists.

return {
  number = 4071,
  description = "JOIN - tables available after JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
        "Employees",
      },
    },
    type = "table",
  },
}
