-- Test 4099: MERGE INTO - target table completion

return {
  number = 4099,
  description = "MERGE INTO - target table completion",
  database = "vim_dadbod_test",
  query = "MERGE INTO █",
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
