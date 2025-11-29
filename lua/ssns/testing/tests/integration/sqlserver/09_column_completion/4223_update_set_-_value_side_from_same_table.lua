-- Test 4223: UPDATE SET - value side from same table

return {
  number = 4223,
  description = "UPDATE SET - value side from same table",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Salary = Salary + █",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
