-- Test 4220: HAVING - nested aggregate

return {
  number = 4220,
  description = "HAVING - nested aggregate",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING COUNT(DISTINCT )█ > 1",
  expected = {
    items = {
      includes = {
        "Salary",
        "FirstName",
      },
    },
    type = "column",
  },
}
