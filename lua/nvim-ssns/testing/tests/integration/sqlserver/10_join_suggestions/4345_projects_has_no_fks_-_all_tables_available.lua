-- Test 4345: Projects has no FKs - all tables available

return {
  number = 4345,
  description = "Projects has no FKs - all tables available",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Projects p JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
        "Orders",
      },
    },
    type = "table",
  },
}
