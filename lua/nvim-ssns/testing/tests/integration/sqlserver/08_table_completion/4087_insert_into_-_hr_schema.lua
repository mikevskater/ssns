-- Test 4087: INSERT INTO - hr schema

return {
  number = 4087,
  description = "INSERT INTO - hr schema",
  database = "vim_dadbod_test",
  query = "INSERT INTO hr.█",
  expected = {
    items = {
      includes = {
        "Benefits",
      },
    },
    type = "table",
  },
}
