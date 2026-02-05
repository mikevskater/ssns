-- Test 4626: MERGE - INTO table completion

return {
  number = 4626,
  description = "MERGE - INTO table completion",
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
