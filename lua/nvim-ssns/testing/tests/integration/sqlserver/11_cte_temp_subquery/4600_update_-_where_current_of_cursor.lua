-- Test 4600: UPDATE - WHERE CURRENT OF cursor

return {
  number = 4600,
  description = "UPDATE - WHERE CURRENT OF cursor",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET █ = 'Updated' WHERE CURRENT OF emp_cursor",
  expected = {
    items = {
      includes = {
        "FirstName",
        "Email",
      },
    },
    type = "column",
  },
}
