-- Test 4100: MERGE USING - source table completion

return {
  number = 4100,
  description = "MERGE USING - source table completion",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING █]],
  expected = {
    items = {
      includes = {
        "Departments",
        "Projects",
      },
    },
    type = "table",
  },
}
