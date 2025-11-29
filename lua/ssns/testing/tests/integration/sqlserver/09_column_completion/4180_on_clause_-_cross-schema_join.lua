-- Test 4180: ON clause - cross-schema join

return {
  number = 4180,
  description = "ON clause - cross-schema join",
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
