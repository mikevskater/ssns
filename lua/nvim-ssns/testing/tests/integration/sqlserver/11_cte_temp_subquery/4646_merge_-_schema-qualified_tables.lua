-- Test 4646: MERGE - schema-qualified tables

return {
  number = 4646,
  description = "MERGE - schema-qualified tables",
  database = "vim_dadbod_test",
  query = [[MERGE INTO dbo.Employees AS target
USING hr.█ AS source
ON target.EmployeeID = source.EmployeeID]],
  expected = {
    items = {
      includes_any = {
        "Benefits",
        "EmployeeBenefits",
      },
    },
    type = "table",
  },
}
