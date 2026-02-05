-- Test 4533: Subquery - NOT IN subquery columns

return {
  number = 4533,
  description = "Subquery - NOT IN subquery columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID NOT IN (SELECT █ FROM Departments WHERE Budget < 1000)",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
