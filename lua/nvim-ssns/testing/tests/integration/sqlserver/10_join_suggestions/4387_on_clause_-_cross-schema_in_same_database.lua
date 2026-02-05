-- Test 4387: ON clause - cross-schema in same database

return {
  number = 4387,
  description = "ON clause - cross-schema in same database",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.█",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "BenefitID",
      },
    },
    type = "column",
  },
}
