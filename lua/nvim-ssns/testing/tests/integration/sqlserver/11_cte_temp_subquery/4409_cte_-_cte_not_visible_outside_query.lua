-- Test 4409: CTE - CTE not visible outside query

return {
  number = 4409,
  description = "CTE - CTE not visible outside query",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      excludes = {
        "EmployeeCTE",
        "DeptCTE",
      },
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
