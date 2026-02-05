-- Test 4605: DELETE - WHERE with prefix

return {
  number = 4605,
  description = "DELETE - WHERE with prefix",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WHERE Emp█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
