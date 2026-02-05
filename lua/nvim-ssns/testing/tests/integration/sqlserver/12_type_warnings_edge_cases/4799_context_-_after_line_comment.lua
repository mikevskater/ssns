-- Test 4799: Context - after line comment

return {
  number = 4799,
  description = "Context - after line comment",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees -- comment
WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
