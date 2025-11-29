-- Test 4653: Type compatibility - int = varchar (warning)

return {
  number = 4653,
  description = "Type compatibility - int = varchar (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = FirstN█ame",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "implicit_conversion",
      },
    },
    type = "warning",
  },
}
