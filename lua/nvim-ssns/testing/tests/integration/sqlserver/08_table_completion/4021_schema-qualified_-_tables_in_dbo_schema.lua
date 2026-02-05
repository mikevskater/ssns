-- Test 4021: Schema-qualified - tables in dbo schema
-- When completing "SELECT * FROM dbo.█", only objects from dbo schema should appear
-- This test validates that schema filtering works correctly

local DB = require('nvim-ssns.testing.db_constants')

return {
  number = 4021,
  description = "Schema-qualified - tables in dbo schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.█",
  expected = {
    items = {
      -- Should include ALL queryable objects from dbo schema:
      -- tables, views, synonyms, and table-valued functions
      includes = DB.vim_dadbod_test_dbo_from_objects,

      -- Should exclude: databases, schemas, objects from other schemas/databases
      excludes = DB.get_dbo_excludes_for_vim_dadbod_test(),
    },
    type = "table",
  },
}
