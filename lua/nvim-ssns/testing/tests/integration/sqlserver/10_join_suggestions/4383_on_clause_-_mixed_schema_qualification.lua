-- Test 4383: ON clause - mixed schema qualification

return {
  number = 4383,
  description = "ON clause - mixed schema qualification",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN hr.Benefits b ON e.EmployeeID = b.█",
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
