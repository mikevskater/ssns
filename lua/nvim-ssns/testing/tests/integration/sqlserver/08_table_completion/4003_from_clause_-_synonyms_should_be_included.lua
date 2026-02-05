-- Test 4003: FROM clause - synonyms should be included

return {
  number = 4003,
  description = "FROM clause - synonyms should be included",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      includes = {
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
      },
    },
    type = "table",
  },
}
