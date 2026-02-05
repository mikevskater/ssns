-- Test 4518: Subquery - column from inner subquery WHERE

return {
  number = 4518,
  description = "Subquery - column from inner subquery WHERE",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT * FROM Employees WHERE █) sub",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "Salary",
      },
    },
    type = "column",
  },
}
