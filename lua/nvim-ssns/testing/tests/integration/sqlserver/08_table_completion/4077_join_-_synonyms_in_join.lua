-- Test 4077: JOIN - synonyms in JOIN

return {
  number = 4077,
  description = "JOIN - synonyms in JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN syn_█",
  expected = {
    items = {
      includes = {
        "syn_Depts",
        "syn_Employees",
      },
    },
    type = "table",
  },
}
