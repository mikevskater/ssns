-- Test 4719: Variable assignment - compatible

return {
  number = 4719,
  description = "Variable assignment - compatible",
  database = "vim_dadbod_test",
  query = "DECLARE @id INT; SELECT @id = EmployeeID FRO█M Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
