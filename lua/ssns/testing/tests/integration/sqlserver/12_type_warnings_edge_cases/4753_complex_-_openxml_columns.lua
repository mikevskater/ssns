-- Test 4753: Complex - OPENXML columns

return {
  number = 4753,
  description = "Complex - OPENXML columns",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM OPENXML(@hdoc, '/root/emp') WITH (ID INT, Name VARCHAR(100))",
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
