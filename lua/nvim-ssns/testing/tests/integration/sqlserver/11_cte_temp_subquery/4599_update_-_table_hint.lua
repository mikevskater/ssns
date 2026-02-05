-- Test 4599: UPDATE - table hint

return {
  number = 4599,
  description = "UPDATE - table hint",
  database = "vim_dadbod_test",
  query = "UPDATE Employees WITH (ROWLOCK) SET █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
