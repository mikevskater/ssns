return {
  number = 1,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.]],
  cursor = {
    line = 0,
    col = 18
  },
  expected = {
    type = [[table]],
    items = {
      "Departments",
      "Employees",
      "newTable",
      "Projects",
      "test_table",
      "vw_ActiveEmployees",
      "vw_DepartmentSummary",
      "vw_ProjectStatus",
      "syn_ActiveEmployees",
      "syn_Depts",
      "syn_Employees",
      "syn_ExternalTable",
      "syn_HRBenefits",
      "syn_Staff",
      "syn_TestRecords"
    }
  }
}