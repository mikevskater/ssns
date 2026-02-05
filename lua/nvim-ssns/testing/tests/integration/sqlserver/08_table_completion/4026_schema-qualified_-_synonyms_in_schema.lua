-- Test 4026: Schema-qualified - synonyms in schema

return {
  number = 4026,
  description = "Schema-qualified - synonyms in schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.syn_█",
  expected = {
    items = {
      includes = {
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
      },
    },
    type = "table",
  },
}
