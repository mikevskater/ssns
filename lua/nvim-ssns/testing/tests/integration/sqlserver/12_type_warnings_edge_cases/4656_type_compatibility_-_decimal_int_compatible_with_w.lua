-- Test 4656: Type compatibility - decimal = int (compatible with warning)

return {
  number = 4656,
  description = "Type compatibility - decimal = int (compatible with warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Salary = Employee█ID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
