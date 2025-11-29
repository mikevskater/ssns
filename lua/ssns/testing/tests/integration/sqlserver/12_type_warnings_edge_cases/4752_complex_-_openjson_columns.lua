-- Test 4752: Complex - OPENJSON columns

return {
  number = 4752,
  description = "Complex - OPENJSON columns",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM OPENJSON(@json) WITH (ID INT, Name VARCHAR(100))",
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
