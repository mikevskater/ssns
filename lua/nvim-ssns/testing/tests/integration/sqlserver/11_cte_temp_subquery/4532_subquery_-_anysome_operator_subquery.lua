-- Test 4532: Subquery - ANY/SOME operator subquery

return {
  number = 4532,
  description = "Subquery - ANY/SOME operator subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Salary > ANY (SELECT █ FROM Employees WHERE DepartmentID = 1)",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
