return {
  number = 4,
  description = [[Autocomplete for schemas in different database (cross-db handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM TEST.]],
  cursor = {
    line = 0,
    col = 19
  },
  expected = {
    type = [[schema]],
    items = {
      "dbo"
    }
  }
}