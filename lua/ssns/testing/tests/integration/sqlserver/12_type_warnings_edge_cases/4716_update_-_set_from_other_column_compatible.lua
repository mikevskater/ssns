-- Test 4716: UPDATE - SET from other column compatible

return {
  number = 4716,
  description = "UPDATE - SET from other column compatible",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET DepartmentID = EmployeeID█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
