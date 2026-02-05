-- Test 4337: Complex scenario - mixed aliases and table names

return {
  number = 4337,
  description = "Complex scenario - mixed aliases and table names",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees, Departments d JOIN █",
  expected = {
    items = {
      includes = {
        "Projects",
        "Orders",
      },
    },
    type = "table",
  },
}
