-- Test 4076: JOIN - views in JOIN

return {
  number = 4076,
  description = "JOIN - views in JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN vw_█",
  expected = {
    items = {
      includes = {
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
      },
    },
    type = "table",
  },
}
