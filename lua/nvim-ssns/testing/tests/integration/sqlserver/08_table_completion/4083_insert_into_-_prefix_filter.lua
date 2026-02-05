-- Test 4083: INSERT INTO - prefix filter

return {
  number = 4083,
  description = "INSERT INTO - prefix filter",
  database = "vim_dadbod_test",
  query = "INSERT INTO Emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
