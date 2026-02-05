-- Test 4084: INSERT INTO - bracketed table

return {
  number = 4084,
  description = "INSERT INTO - bracketed table",
  database = "vim_dadbod_test",
  query = "INSERT INTO [Emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
