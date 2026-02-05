-- Test 4008: FROM clause - prefix filter 'syn_'

return {
  number = 4008,
  description = "FROM clause - prefix filter 'syn_'",
  database = "vim_dadbod_test",
  query = "SELECT * FROM syn_█",
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
