-- Test 4707: Expression - DATEDIFF with dates

return {
  number = 4707,
  description = "Expression - DATEDIFF with dates",
  database = "vim_dadbod_test",
  query = "SELECT DATEDIFF(day, HireDate, GETDATE()) F█ROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
