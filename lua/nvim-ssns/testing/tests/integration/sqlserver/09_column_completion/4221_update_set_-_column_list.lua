-- Test 4221: UPDATE SET - column list

return {
  number = 4221,
  description = "UPDATE SET - column list",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
        "Salary",
      },
    },
    type = "column",
  },
}
