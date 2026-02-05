-- Test 4627: MERGE - USING table completion

return {
  number = 4627,
  description = "MERGE - USING table completion",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING █]],
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
