return {
  number = 10,
  description = [[Autocomplete for Objects in database]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
 *
FROM]],
  cursor = {
    line = 3,
    col = 4
  },
  expected = {
    type = [[object]],
    items = {
      "[dbo].[Departments]",
      "[dbo].[Employees]",
      "[dbo].[newTable]",
      "[dbo].[Projects]",
      "[dbo].[test_table]",
      "[hr].[Benefits]",
      "[dbo].[vw_ActiveEmployees]",
      "[dbo].[vw_DepartmentSummary]",
      "[dbo].[vw_ProjectStatus]",
      "[hr].[vw_EmployeeBenefits]",
      "[dbo].[sp_SearchEmployees]",
      "[dbo].[usp_DepartmentBudgetReport]",
      "[dbo].[usp_GetEmployeesByDepartment]",
      "[dbo].[usp_InsertEmployee]",
      "[dbo].[usp_test]",
      "[dbo].[usp_UpdateEmployeeSalary]",
      "[hr].[usp_GetEmployeeBenefits]",
      "[dbo].[fn_CalculateYearsOfService]",
      "[dbo].[fn_GetActiveProjects]",
      "[dbo].[fn_GetEmployeeFullName]",
      "[dbo].[fn_GetEmployeesByDepartment]",
      "[dbo].[fn_GetEmployeesBySalaryRange]",
      "[hr].[fn_GetTotalBenefitCost]",
      "[Branch].[AllDivisions]",
      "[Branch].[CentralDivision]",
      "[Branch].[DivisionMetrics]",
      "[Branch].[EasternDivision]",
      "[Branch].[GetDivisionMetrics]",
      "[Branch].[WesternDivision]",
      "[dbo].[syn_ActiveEmployees]",
      "[dbo].[syn_Depts]",
      "[dbo].[syn_Employees]",
      "[dbo].[syn_ExternalTable]",
      "[dbo].[syn_HRBenefits]",
      "[dbo].[syn_Staff]",
      "[dbo].[syn_TestRecords]",
      "TEST",
      "Branch_Prod"
    }
  }
}