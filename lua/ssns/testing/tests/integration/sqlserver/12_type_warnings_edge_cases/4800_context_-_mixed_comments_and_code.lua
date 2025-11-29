-- Test 4800: Context - mixed comments and code

return {
  number = 4800,
  description = "Context - mixed comments and code",
  database = "vim_dadbod_test",
  query = "SELECT /* col */  /* more */ FROM /* table */ Employees WHERE /* condition */█  = 1",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "IsActive",
      },
    },
    type = "column",
  },
}
