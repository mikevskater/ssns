return {
  number = 5,
  description = [[Autocomplete for tables in schemas in different database (cross-db handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM TEST.dbo.]],
  cursor = {
    line = 0,
    col = 23
  },
  expected = {
    type = [[table]],
    items = {
      "Records"
    }
  }
}