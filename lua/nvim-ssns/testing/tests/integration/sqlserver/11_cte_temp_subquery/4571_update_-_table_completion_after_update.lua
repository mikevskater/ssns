-- Test 4571: UPDATE - table completion after UPDATE

return {
  number = 4571,
  description = "UPDATE - table completion after UPDATE",
  database = "vim_dadbod_test",
  query = "UPDATE █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
