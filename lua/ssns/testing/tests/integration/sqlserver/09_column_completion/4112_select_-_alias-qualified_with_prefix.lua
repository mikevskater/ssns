-- Test 4112: SELECT - alias-qualified with prefix

return {
  number = 4112,
  description = "SELECT - alias-qualified with prefix",
  database = "vim_dadbod_test",
  query = "SELECT e.First█ FROM Employees e",
  expected = {
    items = {
      excludes = {
        "LastName",
      },
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
