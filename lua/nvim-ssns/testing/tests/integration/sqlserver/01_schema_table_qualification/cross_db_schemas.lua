return {
  number = 4,
  description = [[Autocomplete for schemas in different database (cross-db handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM TEST.█]],
  expected = {
    type = [[schema]],
    items = {
      includes = {
        "dbo" -- TEST database only has dbo schema
      },
      excludes = {
        -- Schemas from vim_dadbod_test should not appear
        "hr",
        "Branch",
        -- Tables should not appear at schema level
        "Records",
        "Employees",
        "Departments"
      }
    }
  }
}