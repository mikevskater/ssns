return {
  number = 2,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM hr.]],
  cursor = {
    line = 0,
    col = 17
  },
  expected = {
    type = [[table]],
    items = {
      "Benefits",
      "vw_EmployeeBenefits"
    }
  }
}