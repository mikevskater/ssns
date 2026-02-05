-- Test 4541: Subquery - empty derived table alias
-- SKIPPED: Invalid SQL - derived tables require an alias in SQL Server

return {
  number = 4541,
  description = "Subquery - empty derived table alias",
  database = "vim_dadbod_test",
  skip = true,  -- Invalid SQL: derived tables require aliases
  query = "SELECT █ FROM (SELECT * FROM Employees)",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
