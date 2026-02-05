-- Test 4537: Subquery - LIKE with subquery (edge case)

return {
  number = 4537,
  description = "Subquery - LIKE with subquery (edge case)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE FirstName LIKE (SELECT █ FROM Employees WHERE EmployeeID = 1)",
  expected = {
    items = {
      includes_any = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
