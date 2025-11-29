-- Test 4654: Type compatibility - date = int (warning)

return {
  number = 4654,
  description = "Type compatibility - date = int (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE HireDate = Employee█ID",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
