-- Test 4623: DELETE - table hint

return {
  number = 4623,
  description = "DELETE - table hint",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WITH (ROWLOCK) WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "IsActive",
      },
    },
    type = "column",
  },
}
