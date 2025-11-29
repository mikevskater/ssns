-- Test 4681: JOIN ON - cross-schema type consistency

return {
  number = 4681,
  description = "JOIN ON - cross-schema type consistency",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.EmployeeID█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
