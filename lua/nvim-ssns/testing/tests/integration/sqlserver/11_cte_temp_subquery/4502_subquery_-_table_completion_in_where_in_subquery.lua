-- Test 4502: Subquery - table completion in WHERE IN subquery

return {
  number = 4502,
  description = "Subquery - table completion in WHERE IN subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM █)",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
