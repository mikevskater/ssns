-- Test 4591: UPDATE - computed column excluded from SET

return {
  number = 4591,
  description = "UPDATE - computed column excluded from SET",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
