return {
  number = 3,
  description = [[Autocomplete for tables in schema (Multi-line SELECT handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT 
* 
FROM
dbo.]],
  cursor = {
    line = 3,
    col = 4
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