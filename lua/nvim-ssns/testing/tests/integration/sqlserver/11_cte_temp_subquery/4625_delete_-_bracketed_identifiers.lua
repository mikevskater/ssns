-- Test 4625: DELETE - bracketed identifiers

return {
  number = 4625,
  description = "DELETE - bracketed identifiers",
  database = "vim_dadbod_test",
  query = "DELETE FROM [Employees] WHERE [█].",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
