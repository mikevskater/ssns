-- Test 4085: INSERT INTO - multiline

return {
  number = 4085,
  description = "INSERT INTO - multiline",
  database = "vim_dadbod_test",
  query = [[INSERT INTO
  █]],
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
