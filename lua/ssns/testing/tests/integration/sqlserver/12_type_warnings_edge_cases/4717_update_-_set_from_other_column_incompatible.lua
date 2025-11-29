-- Test 4717: UPDATE - SET from other column incompatible

return {
  number = 4717,
  description = "UPDATE - SET from other column incompatible",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET EmployeeID = FirstName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
