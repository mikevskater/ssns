-- Test 4512: Subquery - column completion in WHERE IN subquery

return {
  number = 4512,
  description = "Subquery - column completion in WHERE IN subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT █ FROM Departments)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
